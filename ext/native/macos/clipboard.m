#import <AppKit/AppKit.h>
#include <string.h>

int clipboard_read_html(char *out, int out_size) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *html = [pb stringForType:NSPasteboardTypeHTML];
    if (!html) return 0;
    strncpy(out, html.UTF8String ?: "", out_size - 1);
    out[out_size - 1] = '\0';
    return 1;
}

void clipboard_write_html(const char *html) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:@(html) forType:NSPasteboardTypeHTML];
}

int clipboard_read_image(char *out, int out_size) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSData *data = [pb dataForType:NSPasteboardTypePNG];
    if (!data) {
        NSData *tiff = [pb dataForType:NSPasteboardTypeTIFF];
        if (tiff) {
            NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff];
            data = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        }
    }
    if (!data) return 0;
    NSString *b64 = [data base64EncodedStringWithOptions:0];
    strncpy(out, b64.UTF8String ?: "", out_size - 1);
    out[out_size - 1] = '\0';
    return 1;
}

void clipboard_write_image(const char *data_url) {
    NSString *str = @(data_url);
    NSRange comma = [str rangeOfString:@","];
    NSString *b64 = (comma.location != NSNotFound) ? [str substringFromIndex:comma.location + 1] : str;
    NSData *data = [[NSData alloc] initWithBase64EncodedString:b64
                                                       options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!data) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setData:data forType:NSPasteboardTypePNG];
}
