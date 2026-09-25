// Build: clang -fobjc-arc spec/support/mac_toolbar_smoke.m ext/native/darwin/window.m -framework AppKit -framework WebKit -o /tmp/lune-toolbar-smoke
// Run /tmp/lune-toolbar-smoke for assertions, or add --visual for a 60-second preview.
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#include <assert.h>
#include <string.h>

void lune_set_toolbar_style(void *window, int style);
void set_titlebar_transparent(void *window, BOOL full_size_content);
void hide_title(void *window);

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSMutableArray<NSWindow *> *windows = [NSMutableArray array];
        for (int i = 0; i < 4; i++) {
            BOOL fullSize = i >= 2;
            int style = i % 2 == 0 ? 3 : 4;
            NSWindow *w = [[NSWindow alloc]
                initWithContentRect:NSMakeRect(50 + (i % 2) * 510, 80 + (i / 2) * 330, 480, 260)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                backing:NSBackingStoreBuffered defer:NO];
            w.releasedWhenClosed = NO;
            WKWebView *webview = [[WKWebView alloc] initWithFrame:w.contentView.bounds];
            w.contentView = webview;
            NSString *label = [NSString stringWithFormat:@"%@ · %@",
                style == 3 ? @"Unified" : @"UnifiedCompact",
                fullSize ? @"Full-size content" : @"Standard content"];
            w.title = label;
            [webview loadHTMLString:[NSString stringWithFormat:
                @"<body style='margin:0;background:#edf2f7;font:18px system-ui'><main style='padding:80px 24px'><b>%@</b><p>Native toolbar geometry</p></main></body>", label] baseURL:nil];
            assert(w.toolbar == nil);
            if (fullSize) set_titlebar_transparent((__bridge void *)w, YES);
            lune_set_toolbar_style((__bridge void *)w, style);
            assert(w.toolbar != nil && w.toolbar.visible);
            NSToolbar *toolbar = w.toolbar;
            // Verify all bridge values and that reapplying preserves the toolbar.
            if (@available(macOS 11.0, *)) {
                NSWindowToolbarStyle expected[] = {NSWindowToolbarStyleAutomatic,
                    NSWindowToolbarStyleExpanded, NSWindowToolbarStylePreference,
                    NSWindowToolbarStyleUnified, NSWindowToolbarStyleUnifiedCompact};
                for (int value = 0; value < 5; value++) {
                    lune_set_toolbar_style((__bridge void *)w, value);
                    assert(w.toolbarStyle == expected[value]);
                    assert(w.toolbar == toolbar);
                }
            }
            lune_set_toolbar_style((__bridge void *)w, style);
            if (fullSize) hide_title((__bridge void *)w);
            for (NSWindow *other in windows) assert(other.toolbar != w.toolbar);
            [windows addObject:w];
        }
        puts("Native toolbar assertions passed (four independent windows, all five styles).");
        fflush(stdout);
        if ((argc > 1 && strcmp(argv[1], "--visual") == 0) ||
            [NSBundle.mainBundle.bundlePath hasSuffix:@".app"]) {
            for (NSWindow *w in windows) [w makeKeyAndOrderFront:nil];
            [NSApp activateIgnoringOtherApps:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [NSApp terminate:nil];
            });
            [NSApp run];
        }
    }
    return 0;
}
