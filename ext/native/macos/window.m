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

// ── File drop ─────────────────────────────────────────────────────────────────

typedef void (*LuneDropCallback)(const char *paths_json, void *userdata);

@interface LuneDropView : NSView <NSDraggingDestination>
@property (nonatomic) LuneDropCallback dropCallback;
@property (nonatomic) void *dropUserdata;
@end

@implementation LuneDropView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    }
    return self;
}

- (BOOL)isOpaque { return NO; }

// Must return self so the drag system's hit-test can locate this view.
// The check against contentView.frame excludes the title bar, so traffic
// lights are never intercepted regardless of window style.
- (NSView *)hitTest:(NSPoint)point {
    if (self.window && !NSPointInRect(point, self.window.contentView.frame))
        return nil;
    return self;
}

// Forward regular mouse/scroll events to the WKWebView so all normal web
// interactions (click, scroll, text-selection) continue to work.
- (void)mouseDown:(NSEvent *)e      { [self.window.contentView mouseDown:e]; }
- (void)mouseUp:(NSEvent *)e        { [self.window.contentView mouseUp:e]; }
- (void)mouseDragged:(NSEvent *)e   { [self.window.contentView mouseDragged:e]; }
- (void)rightMouseDown:(NSEvent *)e { [self.window.contentView rightMouseDown:e]; }
- (void)rightMouseUp:(NSEvent *)e   { [self.window.contentView rightMouseUp:e]; }
- (void)scrollWheel:(NSEvent *)e    { [self.window.contentView scrollWheel:e]; }

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if (![[sender.draggingPasteboard types] containsObject:NSPasteboardTypeFileURL])
        return NSDragOperationNone;
    return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    if (![[sender.draggingPasteboard types] containsObject:NSPasteboardTypeFileURL])
        return NSDragOperationNone;
    return NSDragOperationCopy;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender { return YES; }

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pb = sender.draggingPasteboard;
    NSArray<NSURL *> *urls = [pb readObjectsForClasses:@[NSURL.class]
                                               options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    if (!urls.count) return NO;

    NSMutableString *json = [NSMutableString stringWithString:@"["];
    for (NSUInteger i = 0; i < urls.count; i++) {
        NSString *path = urls[i].path;
        path = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        path = [path stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        if (i > 0) [json appendString:@","];
        [json appendFormat:@"\"%@\"", path];
    }
    [json appendString:@"]"];

    if (self.dropCallback)
        self.dropCallback([json UTF8String], self.dropUserdata);
    return YES;
}

@end

void setup_file_drop(void *window, LuneDropCallback callback, void *userdata) {
    NSWindow *w = (__bridge NSWindow *)window;

    // Unregister the WKWebView from all drag types. Without this it intercepts
    // every file drag before our overlay can see it (the same reason Wails has
    // a DisableWebViewDrop option).
    [w.contentView unregisterDraggedTypes];

    // Add the overlay as a sibling of the WKWebView (in the frame view) so it
    // sits above the webview in z-order and genuinely receives drag hit-tests.
    NSView *host = w.contentView.superview ?: w.contentView;
    LuneDropView *dropView = [[LuneDropView alloc] initWithFrame:host.bounds];
    dropView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    dropView.dropCallback = callback;
    dropView.dropUserdata = userdata;
    [host addSubview:dropView positioned:NSWindowAbove relativeTo:nil];
}

// ── Window controls ────────────────────────────────────────────────────────────

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
