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
static void attemptConnection();
static void xorDecrypt(const char *input, char *output, const char *key, size_t len);

// Variables
static int sockfd = -1;
static dispatch_source_t readTimer;
static SCNetworkReachabilityRef reachabilityRef;
static int reconnectionAttempts = 0;
static dispatch_source_t reconnectTimer;

