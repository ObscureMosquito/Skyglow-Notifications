#import "SNGuideViewController.h"

#define kBundlePath @"/Library/PreferenceBundles/SkyglowNotificationsDaemonPreferences.bundle"

@implementation GuideViewController

- (void)loadView {
    self.webView = [[UIWebView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.view = self.webView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSBundle *bundle = [[NSBundle alloc] initWithPath:kBundlePath];
    NSString *htmlPath = [bundle pathForResource:@"guide" ofType:@"html"];
    NSString *htmlContent = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    [self.webView loadHTMLString:htmlContent baseURL:[NSURL fileURLWithPath:[htmlPath stringByDeletingLastPathComponent]]];
}


@end