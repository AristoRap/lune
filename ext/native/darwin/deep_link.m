#import <AppKit/AppKit.h>

typedef void (*LuneDeepLinkCallback)(const char *, void *);

static LuneDeepLinkCallback _callback = NULL;
static void                *_userdata  = NULL;

@interface LuneDeepLinkHandler : NSObject
@end

@implementation LuneDeepLinkHandler
- (void)handleGetURL:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if (url && _callback) {
        _callback([url UTF8String], _userdata);
    }
}
@end

static LuneDeepLinkHandler *_handler = nil;

void lune_deep_link_install(LuneDeepLinkCallback callback, void *userdata) {
    _callback = callback;
    _userdata  = userdata;
    if (!_handler) {
        _handler = [[LuneDeepLinkHandler alloc] init];
        // kInternetEventClass = kAEGetURL = 'GURL' (four-char codes for URL open events)
        [[NSAppleEventManager sharedAppleEventManager]
              setEventHandler:_handler
                  andSelector:@selector(handleGetURL:withReplyEvent:)
                forEventClass:'GURL'
                   andEventID:'GURL'];
    }
}
