#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

typedef struct { int x; int y; int width; int height; } WindowFrame;

// ── Appearance ────────────────────────────────────────────────────────────────

void set_titlebar_transparent(void *window, BOOL full_size_content) {
    NSWindow *w = (__bridge NSWindow *)window;
    w.titlebarAppearsTransparent = YES;
    if (full_size_content)
        w.styleMask |= NSWindowStyleMaskFullSizeContentView;
}

void set_background_transparent(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    // Disable webview's own background so CSS backdrop-filter shows through.
    WKWebView *webview = (WKWebView *)w.contentView;
    [webview setValue:@NO forKey:@"drawsBackground"];
    w.backgroundColor = NSColor.clearColor;
    w.opaque = NO;
}

// ── Title bar ─────────────────────────────────────────────────────────────────

void hide_title(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    w.titleVisibility = NSWindowTitleHidden;
}

// ── Appearance ────────────────────────────────────────────────────────────────
// mode: 0 = auto (system default), 1 = dark, 2 = light

void set_appearance(void *window, int mode) {
    NSWindow *w = (__bridge NSWindow *)window;
    NSAppearance *appearance = nil;
    if (mode == 1)
        appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    else if (mode == 2)
        appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    w.appearance = appearance;
}

// ── Content protection ────────────────────────────────────────────────────────

void set_content_protection(void *window, BOOL enabled) {
    NSWindow *w = (__bridge NSWindow *)window;
    w.sharingType = enabled ? NSWindowSharingNone : NSWindowSharingReadOnly;
}

// ── Always on top ─────────────────────────────────────────────────────────────

void set_always_on_top(void *window, BOOL enabled) {
    NSWindow *w = (__bridge NSWindow *)window;
    w.level = enabled ? NSFloatingWindowLevel : NSNormalWindowLevel;
}

// ── Drag zones ────────────────────────────────────────────────────────────────

// Stores the last left-mousedown event so performWindowDragWithEvent: can use
// it even after the async JS→Crystal round-trip has advanced the event queue.
static NSEvent *_last_mousedown = nil;

void setup_drag_monitor(void) {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
                                          handler:^NSEvent *(NSEvent *e) {
        _last_mousedown = e;
        return e;
    }];
}

void start_window_drag(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    if (_last_mousedown)
        [w performWindowDragWithEvent:_last_mousedown];
}

void minimize(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    [w miniaturize:nil];
}

void maximize(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    [w zoom:nil];
}

void set_title(void *window, const char *title) {
    NSWindow *w = (__bridge NSWindow *)window;
    [w setTitle:[NSString stringWithUTF8String:title]];
}

void set_size(void *window, int width, int height) {
    NSWindow *w = (__bridge NSWindow *)window;
    [w setContentSize:NSMakeSize((CGFloat)width, (CGFloat)height)];
}

void center(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    [w center];
}

WindowFrame get_frame(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    NSRect f = w.frame;
    WindowFrame wf;
    wf.x = (int)f.origin.x;
    wf.y = (int)f.origin.y;
    wf.width = (int)f.size.width;
    wf.height = (int)f.size.height;
    return wf;
}

void set_frame(void *window, int x, int y, int width, int height) {
    NSWindow *w = (__bridge NSWindow *)window;
    [w setFrame:NSMakeRect((CGFloat)x, (CGFloat)y, (CGFloat)width, (CGFloat)height)
        display:YES animate:NO];
}
