#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

typedef struct { int x; int y; int width; int height; } WindowFrame;

// Window operations called from JS binding callbacks may arrive on any Crystal
// fiber thread.  AppKit requires UI calls on the main thread.
static void run_on_main(void (^block)(void)) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

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

void hide_traffic_lights(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    [[w standardWindowButton:NSWindowCloseButton]     setHidden:YES];
    [[w standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
    [[w standardWindowButton:NSWindowZoomButton]       setHidden:YES];
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

// Stores the last left-mousedown event so performWindowDragWithEvent: and
// beginDraggingSessionWithItems:event:source: can use it after the async
// JS→Crystal round-trip has advanced the event queue.
static NSEvent *_last_mousedown = nil;
static BOOL     _drag_monitor_active = NO;

void setup_drag_monitor(void) {
    if (_drag_monitor_active) return;
    _drag_monitor_active = YES;
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
                                          handler:^NSEvent *(NSEvent *e) {
        _last_mousedown = e;
        return e;
    }];
}

void start_window_drag(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{ if (_last_mousedown) [w performWindowDragWithEvent:_last_mousedown]; });
}

// ── File drop ─────────────────────────────────────────────────────────────────

// Callback fired on drop: JSON string {"x":N,"y":N,"paths":[...]}
typedef void (*LuneDropCallback)(const char *json, void *userdata);

@interface LuneDropView : NSView <NSDraggingDestination>
@property (nonatomic) LuneDropCallback  dropCallback;
@property (nonatomic) void             *dropUserdata;
// JS function to call with drag position, e.g. "window.__lune_drag_pos".
// nil disables zone highlighting.
@property (nonatomic, copy) NSString   *dragPosFn;
// JS function to call with the dropped paths, e.g. "window.__lune.dropCheck".
// When set, performDragOperation evaluates `dropCheckFn(x, y, paths_json)`
// directly via evaluateJavaScript: — bypassing Crystal's wv.dispatch round-trip,
// so the drop event isn't queued behind pending dragPos updates.
@property (nonatomic, copy) NSString   *dropCheckFn;
// Coalescing: only one evaluateJavaScript: in-flight at a time.
// pendingX/Y track the latest position; evalQueued gates re-entry.
@property (nonatomic) int               pendingX;
@property (nonatomic) int               pendingY;
@property (nonatomic) BOOL              evalQueued;
@end

@implementation LuneDropView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
        self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.pendingX = -1;
        self.pendingY = -1;
    }
    return self;
}

- (BOOL)isOpaque { return NO; }

// Must return self so the drag system's hit-test can locate this view.
// Exclude points outside the content view, and also explicitly pass through
// clicks on the standard window buttons — with NSWindowStyleMaskFullSizeContentView
// the content view spans the titlebar, so the frame check alone isn't enough.
- (NSView *)hitTest:(NSPoint)point {
    if (self.window && !NSPointInRect(point, self.window.contentView.frame))
        return nil;
    NSWindowButton btns[] = { NSWindowCloseButton, NSWindowMiniaturizeButton, NSWindowZoomButton };
    for (int i = 0; i < 3; i++) {
        NSButton *btn = [self.window standardWindowButton:btns[i]];
        if (btn && NSPointInRect(point, [self.superview convertRect:btn.bounds fromView:btn]))
            return nil;
    }
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

- (NSPoint)_dropCSSPoint:(id<NSDraggingInfo>)sender {
    NSView *cv = self.window.contentView;
    NSPoint loc = [cv convertPoint:sender.draggingLocation fromView:nil];
    // WKWebView is flipped (isFlipped=YES, origin top-left), so convertPoint already
    // gives viewport coordinates. Only flip if the view uses bottom-left origin.
    CGFloat y = cv.isFlipped ? loc.y : cv.bounds.size.height - loc.y;
    return NSMakePoint(loc.x, y);
}

// Flush the latest pending position to JS. Called directly from drag handlers
// (avoiding the Crystal wv.dispatch→wv.eval double-async hop that caused stale
// queues and glitchy highlights). The completionHandler gate ensures at most one
// evaluateJavaScript: is in-flight; if the position changed while we were waiting,
// we immediately fire again with the latest coordinates.
- (void)_flushDragPos {
    NSString *fn = self.dragPosFn;
    if (!fn) return;
    int x = self.pendingX, y = self.pendingY;
    NSString *js = [NSString stringWithFormat:@"%@(%d,%d)", fn, x, y];
    __weak typeof(self) weak = self;
    [(WKWebView *)self.window.contentView evaluateJavaScript:js completionHandler:^(id r, NSError *e) {
        LuneDropView *s = weak;
        if (!s) return;
        s.evalQueued = NO;
        if (s.pendingX != x || s.pendingY != y) {
            s.evalQueued = YES;
            [s _flushDragPos];
        }
    }];
}

- (void)_scheduleDragPos:(int)x y:(int)y {
    self.pendingX = x;
    self.pendingY = y;
    if (!self.evalQueued) {
        self.evalQueued = YES;
        [self _flushDragPos];
    }
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if (![[sender.draggingPasteboard types] containsObject:NSPasteboardTypeFileURL])
        return NSDragOperationNone;
    if (self.dragPosFn) {
        NSPoint p = [self _dropCSSPoint:sender];
        [self _scheduleDragPos:(int)p.x y:(int)p.y];
    }
    return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
    if (![[sender.draggingPasteboard types] containsObject:NSPasteboardTypeFileURL])
        return NSDragOperationNone;
    if (self.dragPosFn) {
        NSPoint p = [self _dropCSSPoint:sender];
        [self _scheduleDragPos:(int)p.x y:(int)p.y];
    }
    return NSDragOperationCopy;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    if (self.dragPosFn) [self _scheduleDragPos:-1 y:-1];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender { return YES; }

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pb = sender.draggingPasteboard;
    NSArray<NSURL *> *urls = [pb readObjectsForClasses:@[NSURL.class]
                                               options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    if (!urls.count) return NO;

    NSPoint p = [self _dropCSSPoint:sender];

    NSMutableString *pathsJson = [NSMutableString stringWithString:@"["];
    for (NSUInteger i = 0; i < urls.count; i++) {
        NSString *path = urls[i].path;
        path = [path stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        path = [path stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        if (i > 0) [pathsJson appendString:@","];
        [pathsJson appendFormat:@"\"%@\"", path];
    }
    [pathsJson appendString:@"]"];

    NSString *json = [NSString stringWithFormat:@"{\"x\":%d,\"y\":%d,\"paths\":%@}",
                      (int)p.x, (int)p.y, pathsJson];

    // Fire dropCheck directly into the WKWebView before anything else, so it
    // doesn't queue behind any pending dragPos evals. The string-quoted paths
    // JSON survives a round-trip through JSON.parse on the JS side.
    if (self.dropCheckFn) {
        NSString *escaped = [pathsJson stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        escaped           = [escaped   stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
        NSString *js = [NSString stringWithFormat:@"%@(%d,%d,\"%@\")",
                        self.dropCheckFn, (int)p.x, (int)p.y, escaped];
        [(WKWebView *)self.window.contentView evaluateJavaScript:js completionHandler:nil];
    }

    if (self.dropCallback)
        self.dropCallback([json UTF8String], self.dropUserdata);
    return YES;
}

@end

// Prevents the WKWebView from intercepting file drags before our overlay sees them.
// Equivalent to Wails' DisableWebViewDrop. Safe to call independently of setup_file_drop.
void disable_webview_drop(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    [w.contentView unregisterDraggedTypes];
}

// drag_pos_fn:  JS function name to call with (x, y) on every drag-move, e.g.
//               "window.__lune.dragPos". Pass NULL to disable zone highlighting.
// drop_check_fn: JS function name to call on drop with (x, y, paths_json), e.g.
//               "window.__lune.dropCheck". Pass NULL to skip the direct-eval
//               path (Crystal's wv.dispatch still works as a fallback).
void setup_file_drop(void *window,
                     LuneDropCallback drop_callback, void *drop_userdata,
                     const char *drag_pos_fn,
                     const char *drop_check_fn) {
    NSWindow *w = (__bridge NSWindow *)window;

    // Add the overlay as a sibling of the WKWebView (in the frame view) so it
    // sits above the webview in z-order and genuinely receives drag hit-tests.
    NSView *host = w.contentView.superview ?: w.contentView;
    LuneDropView *dropView = [[LuneDropView alloc] initWithFrame:host.bounds];
    dropView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    dropView.dropCallback = drop_callback;
    dropView.dropUserdata = drop_userdata;
    dropView.dragPosFn    = drag_pos_fn   ? [NSString stringWithUTF8String:drag_pos_fn]   : nil;
    dropView.dropCheckFn  = drop_check_fn ? [NSString stringWithUTF8String:drop_check_fn] : nil;
    [host addSubview:dropView positioned:NSWindowAbove relativeTo:nil];
}

// ── Drag out ──────────────────────────────────────────────────────────────────

// Minimal NSDraggingSource — lets any NSView initiate a drag-out session.
@interface LuneDragSource : NSObject <NSDraggingSource>
@end

@implementation LuneDragSource
- (NSDragOperation)draggingSession:(NSDraggingSession *)session
    sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return NSDragOperationCopy | NSDragOperationMove | NSDragOperationLink;
}
@end

static LuneDragSource *_drag_source = nil;

// Initiates a native drag of local files out of the window.
// paths_json: JSON array of absolute file path strings.
// Requires setup_drag_monitor to have been called so _last_mousedown is set.
void lune_start_drag_out(void *nswindow_ptr, const char *paths_json) {
    if (!_last_mousedown) return;
    if (!_drag_source) _drag_source = [[LuneDragSource alloc] init];

    NSWindow *window = (__bridge NSWindow *)nswindow_ptr;
    NSView   *view   = window.contentView;

    NSData  *data  = [[NSString stringWithUTF8String:paths_json] dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *paths = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (!paths || paths.count == 0) return;

    // Use the stored mousedown position as the drag image origin.
    NSPoint loc = [_last_mousedown locationInWindow];
    NSPoint viewLoc = [view convertPoint:loc fromView:nil];

    NSMutableArray<NSDraggingItem *> *items = [NSMutableArray array];
    for (NSString *path in paths) {
        NSURL *url = [NSURL fileURLWithPath:path];
        if (!url) continue;
        NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:url];
        item.draggingFrame = NSMakeRect(viewLoc.x - 16, viewLoc.y - 16, 32, 32);
        [items addObject:item];
    }
    if (items.count == 0) return;

    run_on_main(^{
        [view beginDraggingSessionWithItems:items event:_last_mousedown source:_drag_source];
    });
}

// ── Menubar / activation policy ───────────────────────────────────────────────

void lune_set_activation_policy_accessory(void) {
    run_on_main(^{
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    });
}

void lune_window_auto_hide_on_resign_key(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    [[NSNotificationCenter defaultCenter]
        addObserverForName:NSWindowDidResignKeyNotification
                    object:w
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        [w orderOut:nil];
    }];
}

void lune_hide_window(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{ [w orderOut:nil]; });
}

void lune_show_window(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{
        [w makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
    });
}

BOOL lune_is_window_visible(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    __block BOOL visible = NO;
    run_on_main(^{ visible = w.isVisible; });
    return visible;
}

// ── Window controls ────────────────────────────────────────────────────────────

void minimize(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{ [w miniaturize:nil]; });
}

void maximize(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{ [w zoom:nil]; });
}

void set_title(void *window, const char *title) {
    NSWindow *w = (__bridge NSWindow *)window;
    NSString *t = [NSString stringWithUTF8String:title];
    run_on_main(^{ [w setTitle:t]; });
}

void set_size(void *window, int width, int height) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{ [w setContentSize:NSMakeSize((CGFloat)width, (CGFloat)height)]; });
}

void center(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{ [w center]; });
}

WindowFrame get_frame(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    __block WindowFrame wf = {0, 0, 0, 0};
    run_on_main(^{
        NSRect f = w.frame;
        wf.x = (int)f.origin.x;
        wf.y = (int)f.origin.y;
        wf.width  = (int)f.size.width;
        wf.height = (int)f.size.height;
    });
    return wf;
}

void set_frame(void *window, int x, int y, int width, int height) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{
        [w setFrame:NSMakeRect((CGFloat)x, (CGFloat)y, (CGFloat)width, (CGFloat)height)
            display:YES animate:NO];
    });
}

void lune_window_close(void *window) {
    NSWindow *w = (__bridge NSWindow *)window;
    run_on_main(^{ [w close]; });
}

// ── Window close observer ──────────────────────────────────────────────────────
// Fires cb(arg) exactly once when the NSWindow receives NSWindowWillCloseNotification.
// Uses NSNotificationCenter (not the delegate) so it never conflicts with the
// webview library's own window delegate.  Retains the observer via associated
// object on the window so ARC cannot release it before the notification fires.
static const char kLuneCloseObserver;

void lune_window_observe_close(void *window, void (*cb)(void *), void *arg) {
    NSWindow *w = (__bridge NSWindow *)window;
    __block id observer = nil;
    observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:NSWindowWillCloseNotification
                    object:w
                     queue:nil
                usingBlock:^(NSNotification *n) {
        cb(arg);
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        objc_setAssociatedObject(w, &kLuneCloseObserver, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        observer = nil;
    }];
    objc_setAssociatedObject(w, &kLuneCloseObserver, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
