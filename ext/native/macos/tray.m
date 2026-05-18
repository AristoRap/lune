#import <AppKit/AppKit.h>

typedef void (*LuneTrayCallback)(void *);
typedef void (*LuneMenuCallback)(const char *, void *);

// NSStatusItem manipulation requires the main thread.
// Binding callbacks can arrive on any Crystal fiber thread.
static void run_on_main(void (^block)(void)) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

static NSStatusItem    *_status_item    = nil;
static LuneTrayCallback _click_cb       = NULL;
static void            *_click_userdata  = NULL;
static LuneMenuCallback _menu_cb        = NULL;
static void            *_menu_userdata   = NULL;

// ── Tray icon click delegate ──────────────────────────────────────────────────

@interface LuneTrayDelegate : NSObject
@end
@implementation LuneTrayDelegate
- (void)trayClicked:(id)sender {
    if (_click_cb) _click_cb(_click_userdata);
}
@end
static LuneTrayDelegate *_delegate = nil;

// ── Menu item click handler ───────────────────────────────────────────────────

@interface LuneMenuHandler : NSObject
@end
@implementation LuneMenuHandler
- (void)itemClicked:(NSMenuItem *)sender {
    if (!_menu_cb) return;
    NSString *itemId = sender.representedObject;
    _menu_cb([itemId UTF8String], _menu_userdata);
}
@end
static LuneMenuHandler *_menu_handler = nil;

// ── Helpers ───────────────────────────────────────────────────────────────────

static void ensure_status_item(void) {
    if (!_status_item) {
        _status_item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        _delegate    = [[LuneTrayDelegate alloc] init];
        _status_item.button.target = _delegate;
        _status_item.button.action = @selector(trayClicked:);
    }
}

static void apply_icon(const char *icon_path) {
    if (icon_path && icon_path[0]) {
        NSString *path = [NSString stringWithUTF8String:icon_path];
        NSImage  *img  = [[NSImage alloc] initWithContentsOfFile:path];
        if (img) {
            img.size = NSMakeSize(18.0, 18.0);
            _status_item.button.image = img;
            return;
        }
    }
    _status_item.button.title = @"●";
}

// ── Public API ────────────────────────────────────────────────────────────────

void tray_show(const char *icon_path, LuneTrayCallback callback, void *userdata) {
    _click_cb       = callback;
    _click_userdata = userdata;
    run_on_main(^{
        ensure_status_item();
        apply_icon(icon_path);
        _status_item.visible = YES;
    });
}

void tray_hide(void) {
    run_on_main(^{ if (_status_item) _status_item.visible = NO; });
}

void tray_set_icon(const char *icon_path) {
    if (!_status_item) return;
    run_on_main(^{ apply_icon(icon_path); });
}

void tray_set_menu(const char **ids, const char **labels, int count,
                   LuneMenuCallback callback, void *userdata) {
    _menu_cb       = callback;
    _menu_userdata = userdata;

    if (!_menu_handler) _menu_handler = [[LuneMenuHandler alloc] init];

    // Build the NSMenu off the main thread (safe — not yet attached to UI).
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;
    for (int i = 0; i < count; i++) {
        if (strcmp(ids[i], "---") == 0) {
            [menu addItem:[NSMenuItem separatorItem]];
        } else {
            NSMenuItem *item = [[NSMenuItem alloc]
                initWithTitle:[NSString stringWithUTF8String:labels[i]]
                       action:@selector(itemClicked:)
                keyEquivalent:@""];
            item.target            = _menu_handler;
            item.representedObject = [NSString stringWithUTF8String:ids[i]];
            item.enabled           = YES;
            [menu addItem:item];
        }
    }

    // Attach to the status item on the main thread.
    run_on_main(^{
        ensure_status_item();
        if (count == 0) {
            _status_item.menu          = nil;
            _status_item.button.target = _delegate;
            _status_item.button.action = @selector(trayClicked:);
        } else {
            _status_item.button.action = nil;
            _status_item.menu          = menu;
        }
    });
}
