#import <AppKit/AppKit.h>

void screen_info(int *width, int *height, double *scale) {
    NSScreen *screen = [NSScreen mainScreen];
    NSRect frame = [screen frame];
    *width  = (int)frame.size.width;
    *height = (int)frame.size.height;
    *scale  = [screen backingScaleFactor];
}
