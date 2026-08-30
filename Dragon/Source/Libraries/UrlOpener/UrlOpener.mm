// UrlOpener.mm

#import <UIKit/UIKit.h>

extern "C" void OpenURL(const char *url) {
    NSURL *nsUrl = [NSURL URLWithString:[NSString stringWithUTF8String:url]];

    if ([[UIApplication sharedApplication] canOpenURL:nsUrl]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:nsUrl options:@{} completionHandler:nil];
        });
    }
}
