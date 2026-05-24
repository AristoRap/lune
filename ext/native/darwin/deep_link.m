#import <AppKit/AppKit.h>

typedef void (*LuneDeepLinkCallback)(const char *, void *);

static LuneDeepLinkCallback _callback = NULL;
static void                *_userdata  = NULL;

// Cold-start buffer. The `kAEGetURL` Apple Event is delivered between
// applicationWillFinishLaunching: and applicationDidFinishLaunching:, which is
// *before* Crystal-side plugin install runs (the webview engine drives NSApp's
// run loop until applicationDidFinishLaunching: fires and only then returns
// control to Crystal). If we wait until plugin install to register the AE
// handler, the GURL event has already been dispatched to the default (no-op)
// handler and the URL is lost. We register the handler at dyld load time via
// the constructor below and stash any URL that arrives pre-callback here, so
// `lune_deep_link_install` can flush it the moment Crystal attaches its callback.
static NSString *_pending_url = nil;

@interface LuneDeepLinkHandler : NSObject
@end

@implementation LuneDeepLinkHandler
- (void)handleGetURL:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if (!url) return;
    if (_callback) {
        _callback([url UTF8String], _userdata);
    } else {
        // Last-write-wins: if a second URL arrives during the launch window,
        // only the most recent one is replayed. ARC handles the strong assign.
        _pending_url = [url copy];
    }
}
@end

static LuneDeepLinkHandler *_handler = nil;

__attribute__((constructor))
static void lune_deep_link_register_early(void) {
    @autoreleasepool {
        _handler = [[LuneDeepLinkHandler alloc] init];
        // kInternetEventClass = kAEGetURL = 'GURL' (four-char codes for URL open events)
        [[NSAppleEventManager sharedAppleEventManager]
              setEventHandler:_handler
                  andSelector:@selector(handleGetURL:withReplyEvent:)
                forEventClass:'GURL'
                   andEventID:'GURL'];
    }
}

void lune_deep_link_install(LuneDeepLinkCallback callback, void *userdata) {
    _callback = callback;
    _userdata  = userdata;
    if (_pending_url && _callback) {
        const char *utf = [_pending_url UTF8String];
        _callback(utf, _userdata);
        _pending_url = nil;  // ARC releases the previous strong reference
    }
}
