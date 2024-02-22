#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <sys/socket.h>
#import <unistd.h>

// Functions
static void setupTCPConnection();
static void tearDownTCPConnection();
static void readFromSocket();
static void cleanUp();
static void setupReachability();
static void xorDecrypt(const char *input, char *output, const char *key, size_t len);
static void attemptReconnectionWithBackoff();

// Variables
static int sockfd = -1;
static dispatch_source_t readTimer;
static SCNetworkReachabilityRef reachabilityRef;
static int reconnectionAttempts = 0;
static dispatch_source_t reconnectTimer;
static const int maxReconnectionAttempts = 4;
static int currentReconnectionAttempt = 0;
static NSTimeInterval reconnectionDelayTimes[] = {15, 30, 90, 180}; // in seconds
