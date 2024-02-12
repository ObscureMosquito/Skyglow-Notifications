#import <Foundation/Foundation.h>
#import <substrate.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>

#define SERVER_IP "143.47.32.233" // Replace with your server's IP
#define SERVER_PORT 5006          // Replace with your server's port

// Function declarations
static void setupTCPConnection();
static void tearDownTCPConnection();
static void readFromSocket();
static void cleanUp();
static void setupReachability();
static void attemptConnection();
static int sockfd = -1;
static NSDate *lastSuccessfulRead;
static dispatch_source_t readTimer;
static SCNetworkReachabilityRef reachabilityRef;
static int reconnectionAttempts = 0;
static int pongTimeoutTimer;
static dispatch_source_t reconnectTimer;

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    Boolean isReachable = flags & kSCNetworkFlagsReachable;
    if (isReachable && sockfd < 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            setupTCPConnection();
        });
    } else if (!isReachable && sockfd >= 0) {
        tearDownTCPConnection();
    }
}

static void setupTCPConnection() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (sockfd >= 0) {
            close(sockfd);
            dispatch_source_t attemptConnectionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            dispatch_source_set_timer(attemptConnectionTimer, DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
            dispatch_source_set_event_handler(attemptConnectionTimer, ^{
            attemptConnection();
            });
        }

        sockfd = socket(AF_INET, SOCK_STREAM, 0);
        struct timeval readTimeout;
        readTimeout.tv_usec = 0;  // 0 milliseconds
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, sizeof(readTimeout));
        if (sockfd < 0) {
            NSLog(@"Error creating socket");
            return;
        }

        struct sockaddr_in serv_addr;
        memset(&serv_addr, 0, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERVER_PORT);
        inet_pton(AF_INET, SERVER_IP, &serv_addr.sin_addr);

        if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
            NSLog(@"Connection Failed");
            close(sockfd);
            sockfd = -1;
            dispatch_source_t attemptConnectionTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            dispatch_source_set_timer(attemptConnectionTimer, DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
            dispatch_source_set_event_handler(attemptConnectionTimer, ^{
            attemptConnection();
            });
            return;
        }

        // Connection successful, send "RTRV" to the server
        const char *retrieveMessage = "RTRV\n";
        send(sockfd, retrieveMessage, strlen(retrieveMessage), 0);

        // Now set up the readTimer
        if (readTimer) {
            dispatch_source_cancel(readTimer);
        }
        readTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        dispatch_source_set_timer(readTimer, DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
        dispatch_source_set_event_handler(readTimer, ^{
            readFromSocket();
        });
        dispatch_resume(readTimer);
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

static void checkAndAttemptReconnect() {
    if (reconnectionAttempts < 3) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (sockfd < 0) { // Only attempt to reconnect if the socket is not already open
                reconnectionAttempts++;
                setupTCPConnection(); // Attempt to establish a new connection
            }
        });
    } else {
        tearDownTCPConnection();
        reconnectionAttempts = 0; // Reset attempts for future reconnections
    }
}

static void attemptConnection() {
    if (reachabilityRef) {
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags) && (flags & kSCNetworkFlagsReachable) && sockfd < 0) {
            // If there's an active internet connection and the socket is closed, attempt to reconnect
            if (!reconnectTimer) {
                reconnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
                dispatch_source_set_timer(reconnectTimer, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 1 * NSEC_PER_SEC);
                dispatch_source_set_event_handler(reconnectTimer, ^{
                    checkAndAttemptReconnect();
                    dispatch_source_cancel(reconnectTimer);
                    reconnectTimer = NULL; // Reset timer after firing
                });
                dispatch_resume(reconnectTimer);
            }
        }
    }
}

static void sendPingAndAwaitPong() {
    if (sockfd < 0) // Ensure we have a valid socket, if invalid, exit the function early, and attempt to reconnect instead
    {
        tearDownTCPConnection();
        attemptConnection();
        return;
    }

    // Send "PING" message to server
    const char *pingMessage = "PING\n";
    send(sockfd, pingMessage, strlen(pingMessage), 0);

    // Set up a timeout to wait for "pong"
    if (pongTimeoutTimer) {
        dispatch_source_cancel(pongTimeoutTimer); // Cancel any existing timer
    }
    pongTimeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(pongTimeoutTimer, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(pongTimeoutTimer, ^{
        NSLog(@"No pong received within timeout. Connection considered failed.");
        tearDownTCPConnection(); // Close the current connection
        attemptConnection(); // Attempt to reconnect
    });
    dispatch_resume(pongTimeoutTimer);
}

static void readFromSocket() {
    // Check if the socket is invalid; initiate reconnection if necessary
    if (sockfd < 0) {
        //NSLog(@"Socket is closed. Attempting to reconnect...");
        attemptConnection();
        return; // Exit the function early as there's no valid connection to read from
    }

    // Send "READ" to the server
    const char *readMessage = "READ\n";
    send(sockfd, readMessage, strlen(readMessage), 0);

    char buffer[1024] = {0};
    ssize_t bytesRead = read(sockfd, buffer, sizeof(buffer) - 1);

    // Check for read errors or no data read
    if (bytesRead < 0) {
        //NSLog(@"Error reading from socket or connection was lost. Attempting to reconnect...");
        tearDownTCPConnection();
        attemptConnection();
        return; // Exit the function as an error occurred during reading
    } else if (bytesRead == 0) {
        sendPingAndAwaitPong();
        return;
    }

    if (bytesRead > 0) {
        lastSuccessfulRead = [NSDate date];
        NSString *receivedData = [NSString stringWithUTF8String:buffer];
        NSArray *messages = [receivedData componentsSeparatedByString:@"\n"];
        
        // Retrieve the current badge count
        NSInteger currentBadgeCount = [[[NSUserDefaults standardUserDefaults] objectForKey:@"com.Trevir.Discord.badgeCount"] integerValue];
        
        for (NSString *fullMessage in messages) {
            @try {
                NSRange delimiterRange = [fullMessage rangeOfString:@"|<|>"];
                if (delimiterRange.location != NSNotFound) {
                    NSString *uuid = [fullMessage substringToIndex:delimiterRange.location];
                    NSString *messageDetails = [fullMessage substringFromIndex:delimiterRange.location + delimiterRange.length];
                    NSArray *messageComponents = [messageDetails componentsSeparatedByString:@"-)("];
                    if (messageComponents.count >= 3) {
                        NSString *senderName = messageComponents[0];
                        NSString *messageContent = messageComponents[1];
                        NSString *channelId = messageComponents[2]; // Extracted channel ID
                        
                        // Increment the badge count
                        currentBadgeCount += 1;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSDictionary *userInfo = @{ @"aps" : @{ @"badge" : @(currentBadgeCount), @"alert" : [NSString stringWithFormat:@"%@: %@", senderName, messageContent], @"channelId" : channelId } };
                            NSString *topic = @"com.Trevir.Discord";
                            APSIncomingMessage *message = [[%c(APSIncomingMessage) alloc] initWithTopic:topic userInfo:userInfo];
                            [[%c(SBRemoteNotificationServer) sharedInstance] connection:nil didReceiveIncomingMessage:message];
                        });
                        
                        // Save the updated badge count
                        [[NSUserDefaults standardUserDefaults] setObject:@(currentBadgeCount) forKey:@"com.Trevir.Discord.badgeCount"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        NSString *ackResponse = [NSString stringWithFormat:@"ACK+%@\n", uuid];
                        const char *ackCStr = [ackResponse UTF8String];
                        send(sockfd, ackCStr, strlen(ackCStr), 0);
                    }
                }
            } @catch (NSException *exception) {
                NSLog(@"Exception occurred: %@", exception);
            }
        }
    }
}


static void cleanUp() {
    tearDownTCPConnection();
    if (reachabilityRef) {
        SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        CFRelease(reachabilityRef);
    }
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


static void notificationsClearedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // Reset the badge count
    [[NSUserDefaults standardUserDefaults] setObject:@(0) forKey:@"com.Trevir.Discord.badgeCount"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

%ctor {
    setupReachability();
    setupTCPConnection();
    readFromSocket();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notificationsClearedCallback, CFSTR("com.Trevir.Discord.badgeReset"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    
}

%dtor {
    tearDownTCPConnection();
    cleanUp();
}