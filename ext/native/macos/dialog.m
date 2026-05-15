#import <AppKit/AppKit.h>
#include <string.h>

int open_file_dialog(const char *title, char *out, int out_size) {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = [NSString stringWithUTF8String:title];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;

    if ([panel runModal] == NSModalResponseOK) {
        NSURL *url = panel.URLs.firstObject;
        const char *path = url.fileSystemRepresentation;
        strncpy(out, path, out_size - 1);
        out[out_size - 1] = '\0';
        return 1;
    }
    return 0;
}

int save_file_dialog(const char *title, const char *default_name, char *out, int out_size) {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = [NSString stringWithUTF8String:title];
    if (default_name && default_name[0]) {
        panel.nameFieldStringValue = [NSString stringWithUTF8String:default_name];
    }

    if ([panel runModal] == NSModalResponseOK) {
        NSURL *url = panel.URL;
        const char *path = url.fileSystemRepresentation;
        strncpy(out, path, out_size - 1);
        out[out_size - 1] = '\0';
        return 1;
    }
    return 0;
}
