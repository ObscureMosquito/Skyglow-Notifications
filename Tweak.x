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
        }

        sockfd = socket(AF_INET, SOCK_STREAM, 0);
        struct timeval readTimeout;
        readTimeout.tv_sec = 0;  // 0 seconds
        readTimeout.tv_usec = 0; // 0 milliseconds, adjust if necessary for non-blocking behavior
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, sizeof(readTimeout));
        if (sockfd < 0) {
            NSLog(@"Error creating socket");
            return;
        }

        int flags = fcntl(sockfd, F_GETFL, 0);
        if (flags < 0) return;
        flags = (flags | O_NONBLOCK);
        if (fcntl(sockfd, F_SETFL, flags) < 0) return; // Set socket to non-blocking

        struct sockaddr_in serv_addr;
        memset(&serv_addr, 0, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERVER_PORT);
        inet_pton(AF_INET, SERVER_IP, &serv_addr.sin_addr);

        if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
            if (errno != EINPROGRESS) { // EINPROGRESS is expected for non-blocking connect
                NSLog(@"Connection Failed");
                close(sockfd);
                sockfd = -1;
                return;
            }
        }

        // Send "RTRV" to the server, consider non-blocking send or move to appropriate place
        const char *retrieveMessage = "RTRV\n";
        send(sockfd, retrieveMessage, strlen(retrieveMessage), 0);

        // Setup dispatch source for reading from the socket
        if (readTimer) {
            dispatch_source_cancel(readTimer);
            readTimer = NULL;
        }
        readTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, sockfd, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
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
    char buffer[1024]; // Adjust size as necessary
    ssize_t bytesRead;

    // Attempt to read data from the socket
    bytesRead = read(sockfd, buffer, sizeof(buffer) - 1);
    if (bytesRead > 0) {
        buffer[bytesRead] = '\0'; // Null-terminate the received data

        char *startOfMessage = strstr(buffer, "|<|>") + 4; // Move past "|<|>"
        if (startOfMessage) {
            char *sender = strtok(startOfMessage, "-)("); // Extract sender
            char *messagePart = strtok(NULL, "-)("); // Extract message

            // Instead of using strtok for the channel ID, find it manually
            if (sender && messagePart) {
                // Manually move past the message part to find the start of the channel ID
                char *channelIdStart = messagePart + strlen(messagePart) + 1; // Move past the null terminator inserted by strtok
                
                // Assuming the message ends with "-)(" before the channel ID, skip this part
                while (*channelIdStart == '-' || *channelIdStart == ')' || *channelIdStart == '(') {
                    channelIdStart++; // Increment pointer to skip these characters
                }

                if (*channelIdStart) { // Check if there's something left for channel ID
                    // Now channelIdStart should point to the beginning of channel ID
                    NSInteger currentBadgeCount = [[[NSUserDefaults standardUserDefaults] objectForKey:@"com.Trevir.Discord.badgeCount"] integerValue];
                    currentBadgeCount += 1;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *senderString = [NSString stringWithUTF8String:sender];
                        NSString *messageString = [NSString stringWithUTF8String:messagePart];
                        NSString *channelIdString = [NSString stringWithUTF8String:channelIdStart]; // Use the adjusted start pointer
                        
                        NSDictionary *userInfo = @{
                            @"aps" : @{
                                @"badge" : @(currentBadgeCount),
                                @"alert" : [NSString stringWithFormat:@"%@: %@", senderString, messageString],
                                @"channelId" : channelIdString
                            }
                        };
                        NSString *topic = @"com.Trevir.Discord";
                        APSIncomingMessage *messageObj = [[%c(APSIncomingMessage) alloc] initWithTopic:topic userInfo:userInfo];
                        [[%c(SBRemoteNotificationServer) sharedInstance] connection:nil didReceiveIncomingMessage:messageObj];
                        
                        [[NSUserDefaults standardUserDefaults] setObject:@(currentBadgeCount) forKey:@"com.Trevir.Discord.badgeCount"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    });

                    const char *ackMessage = "ACK+";
                    write(sockfd, ackMessage, strlen(ackMessage));
                }
            }
        }
    } else if (bytesRead == -1) {
        // Handle read error or non-blocking read return
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
    //wait before reading to not anhiliate springboard before it fully starts, without blocking the main thread
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        readFromSocket();
    });
    readFromSocket();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notificationsClearedCallback, CFSTR("com.Trevir.Discord.badgeReset"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    
}

%dtor {
    tearDownTCPConnection();
    cleanUp();
}