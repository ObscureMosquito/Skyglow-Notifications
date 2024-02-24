#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SNRootListController.h"
#import "SNGuideViewController.h"
#import "SNRegisterAppViewController.h"
#import "SNUnregisterAppViewController.h"

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
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.Skyglow.Notifications.testConnection"), NULL, NULL, TRUE);
        }
    }
}


- (void)registerApp {
	AppsListRegisterViewController *appsListVC = [[AppsListRegisterViewController alloc] init];
    [self.navigationController pushViewController:appsListVC animated:YES];
}

- (void)unregisterApp {
	AppsListUnregisterViewController *appsListVC = [[AppsListUnregisterViewController alloc] init];
    [self.navigationController pushViewController:appsListVC animated:YES];
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


- (void)generateSSLCertificate {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Generating Certificate"
                                                    message:@"\n" // Increase the number of line breaks for additional spacing
                                                   delegate:nil
                                          cancelButtonTitle:nil
                                          otherButtonTitles:nil];
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];

    // Show the alert first to get its dimensions
    [alert show];

    // Delayed adjustment to attempt to accommodate the alert's dynamic layout
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        // Adjust spinner's frame directly to move it lower and possibly make the alert look "thinner"
        CGRect alertBounds = alert.bounds;
        CGPoint center = CGPointMake(CGRectGetMidX(alertBounds), CGRectGetMidY(alertBounds) + 20); // Adjust the Y offset as needed
        activityView.center = center;
        [alert addSubview:activityView];
        [activityView startAnimating];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Generate the keys
        [self generateKeys];

        dispatch_async(dispatch_get_main_queue(), ^{
            // Dismiss the alert
            [alert dismissWithClickedButtonIndex:0 animated:YES];
        });
    });
}


- (void)generateKeys {
    NSString *bundlePath = @"/Library/PreferenceBundles/SkyglowNotificationsDaemonPreferences.bundle/Keys";
    NSString *privateKeyPath = [bundlePath stringByAppendingPathComponent:@"private_key.pem"];
    NSString *publicKeyPath = [bundlePath stringByAppendingPathComponent:@"public_key.pem"];

    // Generate RSA key
    RSA *rsa = RSA_new();
    BIGNUM *bn = BN_new();
    BN_set_word(bn, RSA_F4); // RSA_F4 is a common public exponent

    if (RSA_generate_key_ex(rsa, 2048, bn, NULL) != 1) {
        // Handle key generation error
        NSLog(@"Failed to generate RSA key");
        RSA_free(rsa);
        BN_free(bn);
        return;
    }

    // Save private key
    FILE *privateKeyFile = fopen([privateKeyPath UTF8String], "w");
    if (!privateKeyFile || PEM_write_RSAPrivateKey(privateKeyFile, rsa, NULL, NULL, 0, NULL, NULL) != 1) {
        // Handle error
        NSLog(@"Failed to write private key");
    }
    if (privateKeyFile) fclose(privateKeyFile);

    // Save public key in X.509 SubjectPublicKeyInfo format
    FILE *publicKeyFile = fopen([publicKeyPath UTF8String], "w");
    if (!publicKeyFile || PEM_write_RSA_PUBKEY(publicKeyFile, rsa) != 1) {
        // Handle error
        NSLog(@"Failed to write public key");
    }
    if (publicKeyFile) fclose(publicKeyFile);

    RSA_free(rsa);
    BN_free(bn);
}


@end
