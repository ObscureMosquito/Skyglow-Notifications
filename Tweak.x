#import "KeyManager.h"
#import "Tweak.h"
#import "CommonDefinitions.h"
#import "SettingsUtilities.h"



static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    Boolean isReachable = flags & kSCNetworkFlagsReachable;
    if (isReachable && sockfd < 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSLog(@"Internet connectivity regained. Attempting to setup TCP connection.");
            currentReconnectionAttempt = 0; // Reset attempts as we have internet connectivity now
            setupTCPConnection();
        });
    } else if (!isReachable && sockfd >= 0) {
        NSLog(@"Internet connectivity lost. Tearing down TCP connection.");
        tearDownTCPConnection();
    }
}


static void attemptReconnectWithBackoff() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

    // NSLog(@"Attempting to reconnect with backoff");
    if (currentReconnectionAttempt < maxReconnectionAttempts) {
        NSTimeInterval delay = reconnectionDelayTimes[currentReconnectionAttempt];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            if (sockfd < 0) { // Only attempt to reconnect if the socket is not already open
                NSLog(@"Attempting to reconnect, attempt %d", currentReconnectionAttempt + 1);
                setupTCPConnection();
            }
        });
        currentReconnectionAttempt++;
    } else {
        // NSLog(@"Max reconnection attempts reached. Waiting for a notable event to reattempt.");
        tearDownTCPConnection();
        currentReconnectionAttempt = 0;
    }
    });
}

static void setupReachability() {
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = inet_addr(SERVER_IP);

    reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&address);
    SCNetworkReachabilityContext context = {0, NULL, NULL, NULL, NULL};
    SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context);
    SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}


static void setupTCPConnection() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (sockfd >= 0) {
            close(sockfd);
        }

        sockfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockfd < 0) {
            // NSLog(@"Error creating socket");
            attemptReconnectWithBackoff();
            return;
        }

        // Make the socket non-blocking
        int flags = fcntl(sockfd, F_GETFL, 0);
        if (flags < 0 || fcntl(sockfd, F_SETFL, flags | O_NONBLOCK) < 0) {
            // NSLog(@"Error setting socket to non-blocking");
            close(sockfd);
            sockfd = -1;
            attemptReconnectWithBackoff();
            return;
        }

        struct sockaddr_in serv_addr;
        memset(&serv_addr, 0, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERVER_PORT);
        inet_pton(AF_INET, SERVER_IP, &serv_addr.sin_addr);

        if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0 && errno != EINPROGRESS) {
            // NSLog(@"Initial connection attempt failed");
            close(sockfd);
            sockfd = -1;
            attemptReconnectWithBackoff();
            return;
        }

        // Setup dispatch source for reading from the socket if connection was successful
        if (!readTimer) {
            // NSLog(@"Setting up read timer");
            readTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, sockfd, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            dispatch_source_set_event_handler(readTimer, ^{
                char buffer[1024]; // Adjust buffer size as necessary
                ssize_t bytesRead;

                    // NSLog(@"Received %ld bytes from the server", bytesRead);
                    readFromSocket(); // Process the received data
                    bytesRead = read(sockfd, buffer, sizeof(buffer) - 1);

                if (bytesRead == 0) {
                    // Server closed the connection
                     NSLog(@"Server closed the connection.");
                    close(sockfd);
                    sockfd = -1;
                    dispatch_source_cancel(readTimer);
                    readTimer = NULL;
                    attemptReconnectWithBackoff();
                } else {
                    // An error occurred
                    if (errno != EAGAIN && errno != EWOULDBLOCK) {
                        // NSLog(@"Socket read error, errno: %d", errno);
                        close(sockfd);
                        sockfd = -1;
                        dispatch_source_cancel(readTimer);
                        readTimer = NULL;
                        attemptReconnectWithBackoff();
                    }
                }
            });
            dispatch_resume(readTimer);
        }
    });
}


static void tearDownTCPConnection() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (sockfd >= 0) {
            close(sockfd);
            sockfd = -1;
        }
        if (readTimer) {
            dispatch_source_cancel(readTimer);
            readTimer = NULL;
        }
    });
}


void xorDecrypt(const char *input, char *output, const char *key, size_t len) {
    // NSLog(@"Decrypting message with key, and message: %s %s", key, input);
    size_t keyLen = strlen(key);
    for (size_t i = 0; i < len; ++i) {
        output[i] = input[i] ^ key[i % keyLen];
    }
    output[len] = '\0';
}


static void readFromSocket() {
    char buffer[1024];
    ssize_t bytesRead;

    // Attempt to read data from the socket
    bytesRead = read(sockfd, buffer, sizeof(buffer) - 1);
    if (bytesRead > 0) {
        buffer[bytesRead] = '\0';

        // Decrypt the received data using the XOR key
        char decryptedBuffer[1024];
        XOR_KEY = strdup([[NSUserDefaults standardUserDefaults] stringForKey:@"XORKey"].UTF8String);
        // NSLog(@"XOR Key: %s", XOR_KEY);
        xorDecrypt(buffer, decryptedBuffer, XOR_KEY, bytesRead);
        // NSLog(@"Decrypted message: %s", decryptedBuffer);

        NSData *decryptedData = [NSData dataWithBytes:decryptedBuffer length:strlen(decryptedBuffer)];
        NSError *error;
        // NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
        // NSLog(@"Decrypted string: %@", decryptedString);
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:decryptedData options:0 error:&error];

        if (json) {
            currentReconnectionAttempt = 0; // Reset attempts as we have received a message

            NSString *sender = json[@"sender"];
            NSString *message = json[@"message"];
            NSString *topic = json[@"topic"];

            // NSLog(@"Assigned variables");
            // Logging taken out for performance reasons

            if (sender && message && topic) {
                // NSLog(@"Received message from %@: %@", sender, message);
                NSInteger currentBadgeCount = [[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"com.%@.badgeCount", topic]] integerValue];
                currentBadgeCount += 1;

                dispatch_async(dispatch_get_main_queue(), ^{
                    NSDictionary *apsDict = @{
                        @"badge": @(currentBadgeCount),
                        @"alert": [NSString stringWithFormat:@"%@: %@", sender, message]
                    };

                    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{@"aps": apsDict}];

                    // Extracting extra keys from the JSON response and adding them to the userInfo dictionary
                    NSDictionary *extraInfo = json[@"extra"];
                    if (extraInfo && [extraInfo isKindOfClass:[NSDictionary class]]) {
                        [userInfo addEntriesFromDictionary:extraInfo];
                    }

                    APSIncomingMessage *messageObj = [[%c(APSIncomingMessage) alloc] initWithTopic:topic userInfo:userInfo];
                    [[%c(SBRemoteNotificationServer) sharedInstance] connection:nil didReceiveIncomingMessage:messageObj];

                    [[NSUserDefaults standardUserDefaults] setObject:@(currentBadgeCount) forKey:[NSString stringWithFormat:@"com.%@.badgeCount", topic]];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                });
            }
        }

    } else if (bytesRead == -1) {
        return;
    }
}


static void cleanUp() {
    tearDownTCPConnection();
    if (reachabilityRef) {
        SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFRelease(reachabilityRef);
    }
}


%ctor {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    BOOL isEnabled = [[prefs objectForKey:@"enabled"] boolValue];
    NSString *serverIP = [prefs objectForKey:@"notificationServerAddress"];
    NSString *serverPortStr = [prefs objectForKey:@"notificationServerPort"];
    
    if (!isEnabled || serverIP == nil || serverPortStr == nil) {
        // NSLog(@"Tweak is disabled or server details are missing, running register listener and exiting.");
        // Set up new darwin notification listener for registering and testing the app
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, checkAndRegisterApplication, CFSTR("com.Skyglow.Notifications.register"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, checkAndUnregisterApplication, CFSTR("com.Skyglow.Notifications.unregister"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, testServerConnection, CFSTR("com.Skyglow.Notifications.testConnection"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        return;
    }
    
    int serverPort = [serverPortStr intValue];
    if (serverPort <= 0 || serverPort > 65535 || serverPort == nil || serverIP == nil) {
        // Wait before displaying the alert to not anhiliate springboard before it fully starts, then display the alert in the main thread
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Skyglow Notifications"
                                                            message:@"The server port or IP address are invalid, please check the settings."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
    }
    
    SERVER_IP = strdup([serverIP UTF8String]);
    SERVER_PORT = serverPort;

    requestKeyRefresh();
    setupReachability();
    tearDownTCPConnection();
    // Dont inmediately connect to the server, let SpringBoard start first
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 7 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        setupTCPConnection();
    });
}

%dtor {
    tearDownTCPConnection();
    cleanUp();
}