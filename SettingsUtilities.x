#import "SettingsUtilities.h"
#import "CommonDefinitions.h"


void checkAndRegisterApplication() {
    
    // Get the bundle id as the last registered app in the preferences NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    NSString *bundleIdentifier = [prefs objectForKey:@"lastRegisteredApp"];

    // Get the list of registered bundle IDs
    id registeredBundleIDs = [[%c(SBRemoteNotificationServer) sharedInstance] _allPushRegisteredThirdPartyBundleIDs];
    
    // Check if the bundle identifier is already registered
    if ([registeredBundleIDs containsObject:bundleIdentifier]) {
        // If registered, display an alert indicating so
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Already Registered"
                                                            message:[NSString stringWithFormat:@"%@ is already registered for remote notifications, if you are not receiving notifications, make sure they are enabled in the notifications setting panel.", bundleIdentifier]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
    } else {
        // If not registered, proceed with registration
        NSLog(@"Registering application: %@", bundleIdentifier);
        
        // Obtain or create an instance for your app and register it
        Class SBApplicationControllerClass = objc_getClass("SBApplicationController");
        SBApplication* app = [[SBApplicationControllerClass sharedInstance] applicationWithDisplayIdentifier:bundleIdentifier];
        
        NSString* environment = @"production";
        unsigned notificationTypes = 7; // Badges, sounds, and alerts
        
        // Register the application for remote notifications
        [[%c(SBRemoteNotificationServer) sharedInstance] registerApplication:app forEnvironment:environment withTypes:notificationTypes];
        
    }
}


void checkAndUnregisterApplication() {
    
    // Get the bundle id as the last registered app in the preferences NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    NSString *bundleIdentifier = [prefs objectForKey:@"lastUnregisteredApp"];

    // Get the list of registered bundle IDs
    id registeredBundleIDs = [[%c(SBRemoteNotificationServer) sharedInstance] _allPushRegisteredThirdPartyBundleIDs];
    
    // Check if the bundle identifier is already registered
    if (![registeredBundleIDs containsObject:bundleIdentifier]) {
        // If registered, display an alert indicating so
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not Registered"
                                                            message:[NSString stringWithFormat:@"%@ is not registered for remote notifications, if you wish to recieve notifications, please register it in the submenu.", bundleIdentifier]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
    } else {

        NSLog(@"Unregistering application: %@", bundleIdentifier);
        
        // Obtain or create an instance for your app and unregister it
        Class SBApplicationControllerClass = objc_getClass("SBApplicationController");
        SBApplication* app = [[SBApplicationControllerClass sharedInstance] applicationWithDisplayIdentifier:bundleIdentifier];
        
        // Unregister the application for remote notifications
        [[%c(SBRemoteNotificationServer) sharedInstance] unregisterApplication:app];

        // Present an alert indicating the app has been unregistered
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unregistered"
                                                            message:[NSString stringWithFormat:@"%@ has been unregistered for remote notifications.", bundleIdentifier]
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