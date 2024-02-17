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
        if ([alertView.title isEqualToString:@"Please Disable Daemon"]) {
            [self disableDaemonAndRespring];
        } else if ([alertView.title isEqualToString:@"Register Application"]) {
            [self registerApp];
        } else if ([alertView.title isEqualToString:@"Test Connection"]) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.Trevir.Discord.testConnection"), NULL, NULL, TRUE);
        }
    }
}

- (void)registerApp {
	NSLog(@"Registering application");
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.Trevir.Discord.register"), NULL, NULL, TRUE);
}

- (void)testServerConnection {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    BOOL isEnabled = [[prefs objectForKey:@"enabled"] boolValue];
    if (isEnabled) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Please Disable Daemon" 
                                                        message:@"You can only test the connection while the daemon is disabled, would you like to disable the daemon, restart springboard, and proceed? (You will need to come back and try the test after springboard restarts.)" 
                                                       delegate:self 
                                              cancelButtonTitle:@"Cancel" 
                                              otherButtonTitles:@"Yes, Respring", nil];
        [alert show];
    } else if (!isEnabled) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Test Notification" 
                                                        message:@"Send a test notification to the device" 
                                                       delegate:self 
                                              cancelButtonTitle:@"Cancel" 
                                              otherButtonTitles:@"Proceed", nil];
        [alert show];
    }
}

- (void)disableDaemonAndRespring {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    //set the enabled key to false for NSUserDefaults specific to com.skyglow.sndp
    NSMutableDictionary *newPrefs = [prefs mutableCopy];
    [newPrefs setObject:[NSNumber numberWithBool:NO] forKey:@"enabled"];
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:newPrefs forName:@"com.skyglow.sndp"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    system("killall -9 SpringBoard");
}

@end
