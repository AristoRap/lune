#import <AppKit/AppKit.h>

typedef struct { int x; int y; int width; int height; } WindowFrame;

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
