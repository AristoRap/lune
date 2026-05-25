#import <AppKit/AppKit.h>
#include <string.h>

// [NSPanel runModal] / [NSAlert runModal] call nextEventMatchingMask, which
// AppKit requires to be on the main thread.  Binding callbacks may arrive on
// any Crystal fiber thread, so dispatch synchronously when needed.
static void run_on_main(void (^block)(void)) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

// Parse the cross-FFI filter format ("name|ext1,ext2\nname2|ext3") into a
// flat NSArray of extension strings ("png", "jpg", ...). NSOpenPanel /
// NSSavePanel.allowedFileTypes accepts a flat union list — macOS doesn't
// surface per-group dropdowns the way Win32 / GTK do (the modern API
// `allowedContentTypes` does but needs macOS 11+ + UTType import).
static NSArray<NSString *> *parse_filter_extensions(const char *filters) {
    if (!filters || !filters[0]) return nil;
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSString *str = [NSString stringWithUTF8String:filters];
    for (NSString *entry in [str componentsSeparatedByString:@"\n"]) {
        NSRange pipe = [entry rangeOfString:@"|"];
        NSString *exts = (pipe.location == NSNotFound) ? entry : [entry substringFromIndex:pipe.location + 1];
        for (NSString *ext in [exts componentsSeparatedByString:@","]) {
            NSString *trimmed = [ext stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) [out addObject:trimmed];
        }
    }
    return out.count > 0 ? out : nil;
}

int open_file_dialog(const char *title, const char *filters, char *out, int out_size) {
    __block int ret = 0;
    run_on_main(^{
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.title = [NSString stringWithUTF8String:title];
        panel.canChooseFiles = YES;
        panel.canChooseDirectories = NO;
        panel.allowsMultipleSelection = NO;
        NSArray<NSString *> *exts = parse_filter_extensions(filters);
        if (exts) panel.allowedFileTypes = exts;
        if ([panel runModal] == NSModalResponseOK) {
            NSURL *url = panel.URLs.firstObject;
            const char *path = url.fileSystemRepresentation;
            strncpy(out, path, out_size - 1);
            out[out_size - 1] = '\0';
            ret = 1;
        }
    });
    return ret;
}

int open_dir_dialog(const char *title, char *out, int out_size) {
    __block int ret = 0;
    run_on_main(^{
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.title = [NSString stringWithUTF8String:title];
        panel.canChooseFiles = NO;
        panel.canChooseDirectories = YES;
        panel.allowsMultipleSelection = NO;
        if ([panel runModal] == NSModalResponseOK) {
            NSURL *url = panel.URLs.firstObject;
            const char *path = url.fileSystemRepresentation;
            strncpy(out, path, out_size - 1);
            out[out_size - 1] = '\0';
            ret = 1;
        }
    });
    return ret;
}

int open_files_dialog(const char *title, const char *filters, char *out, int out_size) {
    __block int ret = 0;
    run_on_main(^{
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.title = [NSString stringWithUTF8String:title];
        panel.canChooseFiles = YES;
        panel.canChooseDirectories = NO;
        panel.allowsMultipleSelection = YES;
        NSArray<NSString *> *exts = parse_filter_extensions(filters);
        if (exts) panel.allowedFileTypes = exts;
        if ([panel runModal] == NSModalResponseOK) {
            NSMutableString *result = [NSMutableString string];
            for (NSURL *url in panel.URLs) {
                if (result.length > 0) [result appendString:@"\n"];
                [result appendString:@(url.fileSystemRepresentation)];
            }
            const char *str = result.UTF8String;
            strncpy(out, str, out_size - 1);
            out[out_size - 1] = '\0';
            ret = 1;
        }
    });
    return ret;
}

// type: 0=info, 1=warning, 2=error, 3=question
int message_dialog(int type, const char *title, const char *message, char *out, int out_size) {
    __block int ret = 0;
    run_on_main(^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = [NSString stringWithUTF8String:title];
        alert.informativeText = [NSString stringWithUTF8String:message];

        switch (type) {
            case 1: alert.alertStyle = NSAlertStyleWarning; break;
            case 2: alert.alertStyle = NSAlertStyleCritical; break;
            default: alert.alertStyle = NSAlertStyleInformational; break;
        }

        const char *result;
        if (type == 3) {
            [alert addButtonWithTitle:@"Yes"];
            [alert addButtonWithTitle:@"No"];
            result = ([alert runModal] == NSAlertFirstButtonReturn) ? "Yes" : "No";
        } else {
            [alert addButtonWithTitle:@"Ok"];
            [alert runModal];
            result = "Ok";
        }
        strncpy(out, result, out_size - 1);
        out[out_size - 1] = '\0';
        ret = 1;
    });
    return ret;
}

int save_file_dialog(const char *title, const char *default_name, const char *filters, char *out, int out_size) {
    __block int ret = 0;
    run_on_main(^{
        NSSavePanel *panel = [NSSavePanel savePanel];
        panel.title = [NSString stringWithUTF8String:title];
        if (default_name && default_name[0])
            panel.nameFieldStringValue = [NSString stringWithUTF8String:default_name];
        NSArray<NSString *> *exts = parse_filter_extensions(filters);
        if (exts) panel.allowedFileTypes = exts;
        if ([panel runModal] == NSModalResponseOK) {
            NSURL *url = panel.URL;
            const char *path = url.fileSystemRepresentation;
            strncpy(out, path, out_size - 1);
            out[out_size - 1] = '\0';
            ret = 1;
        }
    });
    return ret;
}
