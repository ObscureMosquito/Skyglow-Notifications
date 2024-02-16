#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SNRootListController.h"
#import "SNGuideViewController.h"

#define kBundlePath @"/Library/PreferenceBundles/SkyglowNotificationsDaemonPreferences.bundle"

@implementation SNRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (void)applyAndRespringAction {
	system("killall -9 SpringBoard");
}

- (void)showGuide {
    GuideViewController *guideVC = [[GuideViewController alloc] init];
    [self.navigationController pushViewController:guideVC animated:YES];
}


- (void) showAlert {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Register Application" 
                                                    message:@"This will register the application for notifications. You will need to accept the notifications permission prompt, Proceed?" 
                                                   delegate:self 
                                          cancelButtonTitle:@"Cancel" 
                                          otherButtonTitles:@"Proceed", nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { 
        [self registerApp];
    }
}

- (void)registerApp {
	NSLog(@"Registering application");
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.Trevir.Discord.register"), NULL, NULL, TRUE);
}


@end
