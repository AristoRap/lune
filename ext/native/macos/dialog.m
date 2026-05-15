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

int open_dir_dialog(const char *title, char *out, int out_size) {
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
        return 1;
    }
    return 0;
}

int open_files_dialog(const char *title, char *out, int out_size) {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = [NSString stringWithUTF8String:title];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = YES;

    if ([panel runModal] == NSModalResponseOK) {
        NSMutableString *result = [NSMutableString string];
        for (NSURL *url in panel.URLs) {
            if (result.length > 0) [result appendString:@"\n"];
            [result appendString:@(url.fileSystemRepresentation)];
        }
        const char *str = result.UTF8String;
        strncpy(out, str, out_size - 1);
        out[out_size - 1] = '\0';
        return 1;
    }
    return 0;
}

// type: 0=info, 1=warning, 2=error, 3=question
int message_dialog(int type, const char *title, const char *message, char *out, int out_size) {
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
    return 1;
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
