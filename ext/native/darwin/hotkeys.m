#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <Carbon/Carbon.h>
#pragma clang diagnostic pop
#import <AppKit/AppKit.h>
#include <string.h>
#include <ctype.h>

typedef void (*LuneHotkeyCallback)(const char *key, void *ctx);

#define MAX_HOTKEYS 64

static LuneHotkeyCallback _cb    = NULL;
static void              *_ud    = NULL;
static EventHandlerRef    _evref = NULL;

typedef struct {
    char           key[128];
    EventHotKeyRef ref;
    int            active;
} HotkeyEntry;

static HotkeyEntry _slots[MAX_HOTKEYS];
static int         _hwm = 0;

// ── key code lookup ───────────────────────────────────────────────────────────

typedef struct { const char *name; UInt32 code; } LuneKeyEntry;
static const LuneKeyEntry KEY_TABLE[] = {
    {"a",0x00},{"b",0x0B},{"c",0x08},{"d",0x02},{"e",0x0E},{"f",0x03},
    {"g",0x05},{"h",0x04},{"i",0x22},{"j",0x26},{"k",0x28},{"l",0x25},
    {"m",0x2E},{"n",0x2D},{"o",0x1F},{"p",0x23},{"q",0x0C},{"r",0x0F},
    {"s",0x01},{"t",0x11},{"u",0x20},{"v",0x09},{"w",0x0D},{"x",0x07},
    {"y",0x10},{"z",0x06},
    {"0",0x1D},{"1",0x12},{"2",0x13},{"3",0x14},{"4",0x15},
    {"5",0x17},{"6",0x16},{"7",0x1A},{"8",0x1C},{"9",0x19},
    {"f1",0x7A},{"f2",0x78},{"f3",0x63},{"f4",0x76},
    {"f5",0x60},{"f6",0x61},{"f7",0x62},{"f8",0x64},
    {"f9",0x65},{"f10",0x6D},{"f11",0x67},{"f12",0x6F},
    {"space",0x31},{"return",0x24},{"enter",0x24},
    {"tab",0x30},{"delete",0x33},{"backspace",0x33},
    {"escape",0x35},{"esc",0x35},
    {"left",0x7B},{"right",0x7C},{"down",0x7D},{"up",0x7E},
    {"home",0x73},{"end",0x77},
    {"pageup",0x74},{"pgup",0x74},{"pagedown",0x79},{"pgdn",0x79},
    {"minus",0x1B},{"-",0x1B},
    {"equal",0x18},{"=",0x18},
    {"bracketleft",0x21},{"[",0x21},
    {"bracketright",0x1E},{"]",0x1E},
    {"backslash",0x2A},
    {"semicolon",0x29},{";",0x29},
    {"quote",0x27},{"'",0x27},
    {"grave",0x32},{"`",0x32},
    {"comma",0x2B},{",",0x2B},
    {"period",0x2F},{".",0x2F},
    {"slash",0x2C},{"/",0x2C},
    {NULL,0}
};

static int keycode_for(const char *n) {
    char lo[32] = {0};
    for (int i = 0; n[i] && i < 31; i++) lo[i] = tolower((unsigned char)n[i]);
    for (int i = 0; KEY_TABLE[i].name != NULL; i++)
        if (strcmp(KEY_TABLE[i].name, lo) == 0) return (int)KEY_TABLE[i].code;
    return -1;
}

// ── accelerator parser ────────────────────────────────────────────────────────

static int parse_acc(const char *acc, UInt32 *code_out, UInt32 *mods_out) {
    char buf[256];
    strncpy(buf, acc, sizeof(buf) - 1);
    buf[sizeof(buf)-1] = '\0';

    UInt32 mods = 0;
    int    code = -1;
    char  *tok  = strtok(buf, "+");
    while (tok) {
        char lo[32] = {0};
        for (int i = 0; tok[i] && i < 31; i++) lo[i] = tolower((unsigned char)tok[i]);
        if      (!strcmp(lo,"ctrl") || !strcmp(lo,"control"))  mods |= controlKey;
        else if (!strcmp(lo,"cmd")  || !strcmp(lo,"command"))  mods |= cmdKey;
        else if (!strcmp(lo,"shift"))                          mods |= shiftKey;
        else if (!strcmp(lo,"alt")  || !strcmp(lo,"option"))   mods |= optionKey;
        else code = keycode_for(lo);
        tok = strtok(NULL, "+");
    }
    if (code < 0) return 0;
    *code_out = (UInt32)code;
    *mods_out = mods;
    return 1;
}

// ── Carbon event handler ──────────────────────────────────────────────────────

static OSStatus hotkey_handler(EventHandlerCallRef next, EventRef event, void *userData) {
    EventHotKeyID hkid;
    if (GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID,
                          NULL, sizeof(hkid), NULL, &hkid) != noErr)
        return noErr;
    int slot = (int)hkid.id;
    if (slot >= 0 && slot < _hwm && _slots[slot].active && _cb)
        _cb(_slots[slot].key, _ud);
    return noErr;
}

static void ensure_handler(void) {
    if (_evref) return;
    EventTypeSpec types[] = {{ kEventClassKeyboard, kEventHotKeyPressed }};
    InstallEventHandler(GetEventDispatcherTarget(), hotkey_handler, 1, types, NULL, &_evref);
}

static void run_on_main(void (^block)(void)) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

// ── public API ────────────────────────────────────────────────────────────────

void lune_hotkeys_init(LuneHotkeyCallback cb, void *userdata) {
    _cb = cb;
    _ud = userdata;
}

int lune_hotkeys_register(const char *accelerator) {
    __block int result = 0;
    run_on_main(^{
        UInt32 code, mods;
        if (!parse_acc(accelerator, &code, &mods)) return;
        ensure_handler();

        int slot = -1;
        for (int i = 0; i < _hwm; i++) {
            if (!_slots[i].active) { slot = i; break; }
        }
        if (slot < 0) {
            if (_hwm >= MAX_HOTKEYS) return;
            slot = _hwm++;
        }

        EventHotKeyID hkid = { 'LUNE', (UInt32)slot };
        EventHotKeyRef ref = NULL;
        if (RegisterEventHotKey(code, mods, hkid,
                                GetEventDispatcherTarget(), 0, &ref) != noErr) return;

        strncpy(_slots[slot].key, accelerator, 127);
        _slots[slot].key[127] = '\0';
        _slots[slot].ref      = ref;
        _slots[slot].active   = 1;
        result = 1;
    });
    return result;
}

int lune_hotkeys_unregister(const char *accelerator) {
    __block int result = 0;
    run_on_main(^{
        for (int i = 0; i < _hwm; i++) {
            if (_slots[i].active && strcmp(_slots[i].key, accelerator) == 0) {
                UnregisterEventHotKey(_slots[i].ref);
                _slots[i].ref    = NULL;
                _slots[i].active = 0;
                _slots[i].key[0] = '\0';
                result = 1;
                break;
            }
        }
    });
    return result;
}

void lune_hotkeys_unregister_all(void) {
    run_on_main(^{
        for (int i = 0; i < _hwm; i++) {
            if (_slots[i].active) {
                UnregisterEventHotKey(_slots[i].ref);
                _slots[i].ref    = NULL;
                _slots[i].active = 0;
                _slots[i].key[0] = '\0';
            }
        }
        _hwm = 0;
    });
}
