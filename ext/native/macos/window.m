#import <AppKit/AppKit.h>

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
