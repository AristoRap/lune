#import <AppKit/AppKit.h>

// popUpMenuPositioningItem:, setMainMenu:, and other AppKit menu calls require
// the main thread.  Binding callbacks may arrive on any Crystal fiber thread.
static void run_on_main(void (^block)(void)) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

// ── Types ─────────────────────────────────────────────────────────────────────

typedef void (*LuneMenuItemCallback)(const char *payload, void *ctx);

static LuneMenuItemCallback _item_cb  = NULL;
static void                *_item_ctx = NULL;

// Context menu — separate callback set so menu-bar and context-menu don't interfere.
static LuneMenuItemCallback _ctx_cb  = NULL;
static void                *_ctx_ctx = NULL;

#define LUNE_TAG_TEXT     0
#define LUNE_TAG_CHECKBOX 1
#define LUNE_TAG_RADIO    2

// ── Click handler ─────────────────────────────────────────────────────────────

@interface LuneMenuItemHandler : NSObject
@end

@implementation LuneMenuItemHandler

- (void)textClicked:(NSMenuItem *)sender {
    if (!_item_cb) return;
    NSString *payload = [NSString stringWithFormat:@"{\"id\":\"%@\"}", sender.representedObject];
    _item_cb([payload UTF8String], _item_ctx);
}

- (void)checkboxClicked:(NSMenuItem *)sender {
    if (!_item_cb) return;
    sender.state = (sender.state == NSControlStateValueOn)
        ? NSControlStateValueOff
        : NSControlStateValueOn;
    BOOL on = (sender.state == NSControlStateValueOn);
    NSString *payload = [NSString stringWithFormat:@"{\"id\":\"%@\",\"checked\":%@}",
                         sender.representedObject, on ? @"true" : @"false"];
    _item_cb([payload UTF8String], _item_ctx);
}

- (void)contextItemClicked:(NSMenuItem *)sender {
    if (!_ctx_cb) return;
    NSString *payload = [NSString stringWithFormat:@"{\"id\":\"%@\"}", sender.representedObject];
    _ctx_cb([payload UTF8String], _ctx_ctx);
}

- (void)radioClicked:(NSMenuItem *)sender {
    if (!_item_cb) return;
    NSMenu *parent = sender.menu;
    NSInteger idx = [parent indexOfItem:sender];

    // Find the contiguous block of radio items that contains idx.
    NSInteger start = idx;
    while (start > 0 && [parent itemAtIndex:start - 1].tag == LUNE_TAG_RADIO) start--;
    NSInteger end = idx;
    while (end < parent.numberOfItems - 1 && [parent itemAtIndex:end + 1].tag == LUNE_TAG_RADIO) end++;

    for (NSInteger i = start; i <= end; i++) {
        [parent itemAtIndex:i].state = (i == idx) ? NSControlStateValueOn : NSControlStateValueOff;
    }

    NSString *payload = [NSString stringWithFormat:@"{\"id\":\"%@\",\"checked\":true}",
                         sender.representedObject];
    _item_cb([payload UTF8String], _item_ctx);
}

@end

static LuneMenuItemHandler *_item_handler = nil;

// ── Role menu builders ────────────────────────────────────────────────────────

static NSMenuItem *build_app_menu_item(NSString *appName) {
    NSMenuItem *container = [[NSMenuItem alloc] init];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:appName];

    [menu addItemWithTitle:[@"About " stringByAppendingString:appName]
                   action:@selector(orderFrontStandardAboutPanel:)
            keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:@"Services" action:nil keyEquivalent:@""];
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    servicesItem.submenu = servicesMenu;
    [menu addItem:servicesItem];
    [NSApp setServicesMenu:servicesMenu];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItemWithTitle:[@"Hide " stringByAppendingString:appName]
                   action:@selector(hide:)
            keyEquivalent:@"h"];

    NSMenuItem *hideOthers = [[NSMenuItem alloc]
        initWithTitle:@"Hide Others"
               action:@selector(hideOtherApplications:)
        keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [menu addItem:hideOthers];

    [menu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItemWithTitle:[@"Quit " stringByAppendingString:appName]
                   action:@selector(terminate:)
            keyEquivalent:@"q"];

    container.submenu = menu;
    return container;
}

static NSMenuItem *build_edit_menu_item(void) {
    NSMenuItem *container = [[NSMenuItem alloc] init];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Edit"];

    [menu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];

    NSMenuItem *redo = [[NSMenuItem alloc]
        initWithTitle:@"Redo"
               action:@selector(redo:)
        keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [menu addItem:redo];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItemWithTitle:@"Cut"        action:@selector(cut:)       keyEquivalent:@"x"];
    [menu addItemWithTitle:@"Copy"       action:@selector(copy:)      keyEquivalent:@"c"];
    [menu addItemWithTitle:@"Paste"      action:@selector(paste:)     keyEquivalent:@"v"];
    [menu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    container.submenu = menu;
    return container;
}

// ── Recursive item builder ────────────────────────────────────────────────────

static void build_children(NSArray *items, NSMenu *menu);

static void build_children(NSArray *items, NSMenu *menu) {
    for (NSDictionary *item in items) {
        NSString *kind = item[@"kind"];

        if ([kind isEqualToString:@"separator"]) {
            [menu addItem:[NSMenuItem separatorItem]];

        } else if ([kind isEqualToString:@"submenu"]) {
            NSString *label = item[@"label"] ?: @"";
            NSMenuItem *container = [[NSMenuItem alloc] initWithTitle:label action:nil keyEquivalent:@""];
            NSMenu *submenu = [[NSMenu alloc] initWithTitle:label];
            submenu.autoenablesItems = NO;
            build_children(item[@"children"] ?: @[], submenu);
            container.submenu = submenu;
            [menu addItem:container];

        } else if ([kind isEqualToString:@"text"]) {
            NSMenuItem *mi = [[NSMenuItem alloc]
                initWithTitle:item[@"label"] ?: @""
                       action:@selector(textClicked:)
                keyEquivalent:item[@"key"] ?: @""];
            mi.keyEquivalentModifierMask = [item[@"modifiers"] unsignedLongLongValue];
            mi.target           = _item_handler;
            mi.enabled          = [item[@"enabled"] boolValue];
            mi.representedObject = item[@"id"] ?: @"";
            mi.tag              = LUNE_TAG_TEXT;
            [menu addItem:mi];

        } else if ([kind isEqualToString:@"checkbox"]) {
            NSMenuItem *mi = [[NSMenuItem alloc]
                initWithTitle:item[@"label"] ?: @""
                       action:@selector(checkboxClicked:)
                keyEquivalent:item[@"key"] ?: @""];
            mi.keyEquivalentModifierMask = [item[@"modifiers"] unsignedLongLongValue];
            mi.target           = _item_handler;
            mi.enabled          = [item[@"enabled"] boolValue];
            mi.state            = [item[@"checked"] boolValue]
                                      ? NSControlStateValueOn : NSControlStateValueOff;
            mi.representedObject = item[@"id"] ?: @"";
            mi.tag              = LUNE_TAG_CHECKBOX;
            [menu addItem:mi];

        } else if ([kind isEqualToString:@"radio"]) {
            NSMenuItem *mi = [[NSMenuItem alloc]
                initWithTitle:item[@"label"] ?: @""
                       action:@selector(radioClicked:)
                keyEquivalent:item[@"key"] ?: @""];
            mi.keyEquivalentModifierMask = [item[@"modifiers"] unsignedLongLongValue];
            mi.target           = _item_handler;
            mi.enabled          = [item[@"enabled"] boolValue];
            mi.state            = [item[@"checked"] boolValue]
                                      ? NSControlStateValueOn : NSControlStateValueOff;
            mi.representedObject = item[@"id"] ?: @"";
            mi.tag              = LUNE_TAG_RADIO;
            [menu addItem:mi];
        }
    }
}

// ── Context menu ──────────────────────────────────────────────────────────────

// Simpler item format: { id, label, enabled?, separator? }
static void build_context_children(NSArray *items, NSMenu *menu) {
    for (NSDictionary *item in items) {
        if ([item[@"separator"] boolValue]) {
            [menu addItem:[NSMenuItem separatorItem]];
            continue;
        }
        NSString *label = item[@"label"] ?: item[@"id"] ?: @"";
        BOOL enabled = item[@"enabled"] != nil ? [item[@"enabled"] boolValue] : YES;
        NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:label
                                                    action:@selector(contextItemClicked:)
                                             keyEquivalent:@""];
        mi.target           = _item_handler;
        mi.enabled          = enabled;
        mi.representedObject = item[@"id"] ?: @"";
        [menu addItem:mi];
    }
}

void lune_show_context_menu(void *nswindow_ptr, float x, float y,
                             const char *json_utf8,
                             LuneMenuItemCallback callback, void *ctx) {
    _ctx_cb  = callback;
    _ctx_ctx = ctx;

    if (!_item_handler) _item_handler = [[LuneMenuItemHandler alloc] init];

    NSData  *data  = [[NSString stringWithUTF8String:json_utf8] dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *items = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!items) return;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    menu.autoenablesItems = NO;
    build_context_children(items, menu);

    // Resolve the view on the main thread so we always use the window that
    // triggered the right-click (its key window at dispatch time), not the
    // handle captured at binding install time which is always the main window.
    // WKWebView is a flipped view (isFlipped=YES), so web clientY maps directly.
    run_on_main(^{
        NSView *view = [NSApp keyWindow].contentView;
        if (!view) return;
        [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(x, y) inView:view];
    });
}

// ── Public API ────────────────────────────────────────────────────────────────

void setup_default_menu(const char *app_name_cstr) {
    NSString *appName = (app_name_cstr && app_name_cstr[0])
        ? [NSString stringWithUTF8String:app_name_cstr]
        : [[NSProcessInfo processInfo] processName];

    NSMenu *menubar = [[NSMenu alloc] init];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:appName];

    [appMenu addItemWithTitle:[@"About " stringByAppendingString:appName]
                      action:@selector(orderFrontStandardAboutPanel:)
               keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *servicesItem = [[NSMenuItem alloc] initWithTitle:@"Services"
                                                          action:nil
                                                   keyEquivalent:@""];
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    servicesItem.submenu = servicesMenu;
    [appMenu addItem:servicesItem];
    [NSApp setServicesMenu:servicesMenu];
    [appMenu addItem:[NSMenuItem separatorItem]];

    [appMenu addItemWithTitle:[@"Hide " stringByAppendingString:appName]
                      action:@selector(hide:)
               keyEquivalent:@"h"];

    NSMenuItem *hideOthers = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                                        action:@selector(hideOtherApplications:)
                                                 keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [appMenu addItem:hideOthers];

    [appMenu addItemWithTitle:@"Show All"
                      action:@selector(unhideAllApplications:)
               keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];

    [appMenu addItemWithTitle:[@"Quit " stringByAppendingString:appName]
                      action:@selector(terminate:)
               keyEquivalent:@"q"];

    appMenuItem.submenu = appMenu;

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];

    NSMenuItem *redo = [[NSMenuItem alloc] initWithTitle:@"Redo"
                                                  action:@selector(redo:)
                                           keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:redo];
    [editMenu addItem:[NSMenuItem separatorItem]];

    [editMenu addItemWithTitle:@"Cut"        action:@selector(cut:)       keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy"       action:@selector(copy:)      keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste"      action:@selector(paste:)     keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    editMenuItem.submenu = editMenu;

    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:windowMenuItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

    [windowMenu addItemWithTitle:@"Minimize"
                          action:@selector(performMiniaturize:)
                   keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom"
                          action:@selector(performZoom:)
                   keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front"
                          action:@selector(arrangeInFront:)
                   keyEquivalent:@""];

    windowMenuItem.submenu = windowMenu;
    [NSApp setWindowsMenu:windowMenu];

    [NSApp setMainMenu:menubar];
}

void lune_set_menu(const char *app_name_cstr, const char *json_utf8,
                   LuneMenuItemCallback callback, void *ctx) {
    _item_cb  = callback;
    _item_ctx = ctx;

    if (!_item_handler) _item_handler = [[LuneMenuItemHandler alloc] init];

    NSString *appName = (app_name_cstr && app_name_cstr[0])
        ? [NSString stringWithUTF8String:app_name_cstr]
        : [[NSProcessInfo processInfo] processName];

    NSData  *data    = [[NSString stringWithUTF8String:json_utf8] dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *topLevel = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!topLevel) return;

    NSMenu *menubar = [[NSMenu alloc] init];
    menubar.autoenablesItems = NO;

    for (NSDictionary *entry in topLevel) {
        NSString *kind = entry[@"kind"];
        if ([kind isEqualToString:@"role_app"]) {
            [menubar addItem:build_app_menu_item(appName)];
        } else if ([kind isEqualToString:@"role_edit"]) {
            [menubar addItem:build_edit_menu_item()];
        } else if ([kind isEqualToString:@"submenu"]) {
            NSString *label = entry[@"label"] ?: @"";
            NSMenuItem *container = [[NSMenuItem alloc] initWithTitle:label action:nil keyEquivalent:@""];
            NSMenu *submenu = [[NSMenu alloc] initWithTitle:label];
            submenu.autoenablesItems = NO;
            build_children(entry[@"children"] ?: @[], submenu);
            container.submenu = submenu;
            [menubar addItem:container];
        }
    }

    run_on_main(^{ [NSApp setMainMenu:menubar]; });
}
