#import "SettingsUtilities.h"
#import "CommonDefinitions.h"


void registerMyApplication() {
    NSLog(@"Registering Discord for remote notifications");
    // Obtain or create an SBApplication instance for your app
    Class SBApplicationControllerClass = objc_getClass("SBApplicationController");
    SBApplication* app = [[SBApplicationControllerClass sharedInstance] applicationWithDisplayIdentifier:@"com.Trevir.Discord"];
    
    NSString* environment = @"production";
    unsigned notificationTypes = 7; // Badges, sounds, and alerts
    
    // Assuming you have access to the class that implements the register method
    [[%c(SBRemoteNotificationServer) sharedInstance] registerApplication:app forEnvironment:environment withTypes:notificationTypes];
}


void listAllowedRemoteApps() {
    id registeredBundleIDs = [[%c(SBRemoteNotificationServer) sharedInstance] _allPushRegisteredThirdPartyBundleIDs];
    
    NSLog(@"All registered third-party bundle IDs: %@", registeredBundleIDs);
    //if com.Trevir.Discord is not in the list, register it
    if (![registeredBundleIDs containsObject:@"com.Trevir.Discord"]) {
        registerMyApplication();
    }
    else {
        //display a UIAlertView to inform the user that the app is already registered
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Discord Notification"
                                                            message:@"Discord Classic is already registered for remote notifications, if you are not receiving notifications, make sure they are enabled in settings."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
    }
}


void testServerConnection() {
    NSDictionary *userInfo = @{
        @"aps" : @{
            @"badge" : @(1),
            @"alert" : @"Test notification",
            @"channelId" : @"test"
        }
    };
    NSString *topic = @"com.Trevir.Discord";
    APSIncomingMessage *messageObj = [[%c(APSIncomingMessage) alloc] initWithTopic:topic userInfo:userInfo];
    [[%c(SBRemoteNotificationServer) sharedInstance] connection:nil didReceiveIncomingMessage:messageObj];
}