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


- (void)sendTestNotification {
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

- (void)showGeneratingKeysAlert {
    alertView = [[UIAlertView alloc] initWithTitle:@"Generating Keys"
                                           message:@"Please wait...\n\n\n" // Extra space for the spinner
                                          delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:nil];
    activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    // Position the spinner in the center of the alert view
    activityIndicatorView.center = CGPointMake(alertView.bounds.size.width / 2, alertView.bounds.size.height - 50);
    [alertView addSubview:activityIndicatorView];
    [activityIndicatorView startAnimating];
    [alertView show];
    
    // Move the key generation to a background thread to keep the UI responsive
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        generateSSLCertificate();
        
        // Once done, dismiss the alert on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [activityIndicatorView stopAnimating];
            [alertView dismissWithClickedButtonIndex:0 animated:YES];
        });
    });
}

void generateSSLCertificate() {
    RSA *rsa = RSA_new();
    BIGNUM *bn = BN_new();
    BN_set_word(bn, RSA_F4); // Use 65537 as the public exponent

    // Generate the RSA key pair
    RSA_generate_key_ex(rsa, 2048, bn, NULL);

    // Extract the private key
    FILE *privateKeyFile = fopen("private_key.pem", "wb");
    PEM_write_RSAPrivateKey(privateKeyFile, rsa, NULL, NULL, 0, NULL, NULL);
    fclose(privateKeyFile);

    // Extract the public key
    FILE *publicKeyFile = fopen("public_key.pem", "wb");
    PEM_write_RSA_PUBKEY(publicKeyFile, rsa);
    fclose(publicKeyFile);

    // Clean up
    RSA_free(rsa);
    BN_free(bn);

    // Now that generation is complete, update UI accordingly (e.g., dismiss alert)
    // This part needs to be run on the main thread if you're updating the UI
}

@end
