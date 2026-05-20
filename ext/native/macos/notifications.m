#import <AppKit/AppKit.h>
#import <UserNotifications/UserNotifications.h>
#import <Security/Security.h>

static void show_via_un(NSString *title, NSString *body) {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    // requestAuthorizationWithOptions is idempotent: already-authorized apps get
    // granted=YES immediately without prompting the user again.
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError *error) {
        if (!granted) return;
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = title;
        content.body  = body;
        content.sound = [UNNotificationSound defaultSound];
        UNTimeIntervalNotificationTrigger *trigger =
            [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.01 repeats:NO];
        UNNotificationRequest *request =
            [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                content:content
                                                trigger:trigger];
        [center addNotificationRequest:request withCompletionHandler:nil];
    }];
}

// Fallback for non-bundled processes (NSUserNotification is dead on macOS 14+).
// NSTask avoids shell injection — arguments are passed directly, not via sh.
static void show_via_osascript(NSString *title, NSString *body) {
    NSString *escaped_title = [title stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped_title = [escaped_title stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *escaped_body = [body stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped_body = [escaped_body stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *script = [NSString stringWithFormat:
        @"display notification \"%@\" with title \"%@\"", escaped_body, escaped_title];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/osascript";
    task.arguments  = @[@"-e", script];
    [task launch];
}

// Returns YES only for processes bearing a certificate-backed Apple code
// signature (Developer cert with a Team Identifier). Ad-hoc and unsigned
// processes return NO and fall back to osascript.
static BOOL has_apple_signing(void) {
    SecCodeRef code = NULL;
    if (SecCodeCopySelf(kSecCSDefaultFlags, &code) != errSecSuccess) return NO;
    CFDictionaryRef info = NULL;
    OSStatus status = SecCodeCopySigningInformation(code, kSecCSSigningInformation, &info);
    CFRelease(code);
    if (status != errSecSuccess || !info) return NO;
    CFStringRef team = (CFStringRef)CFDictionaryGetValue(info, kSecCodeInfoTeamIdentifier);
    BOOL result = team != NULL && CFStringGetLength(team) > 0;
    CFRelease(info);
    return result;
}

void show_notification(const char *title, const char *body) {
    NSString *nsTitle = [NSString stringWithUTF8String:title];
    NSString *nsBody  = [NSString stringWithUTF8String:body];
    if (has_apple_signing()) {
        show_via_un(nsTitle, nsBody);
    } else {
        show_via_osascript(nsTitle, nsBody);
    }
}
