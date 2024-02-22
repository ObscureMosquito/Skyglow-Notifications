#import <Foundation/Foundation.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/err.h>
#include <openssl/bio.h>
#include <openssl/evp.h>

// Functions
void checkAndRefreshKeyIfNeeded();
void requestKeyRefresh();
NSString *decryptWithPrivateKey(NSString *encryptedDataString);
void setupKeyRefreshTimer();
NSData *OpenSSLBase64Decode(NSString *base64String);
