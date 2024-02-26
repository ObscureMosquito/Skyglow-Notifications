#import "KeyManager.h"
#import "CommonDefinitions.h"


void setupKeyRefreshTimer() {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 6 * 60 * 60 * NSEC_PER_SEC), 6 * 60 * 60 * NSEC_PER_SEC, 1 * NSEC_PER_SEC); // 6 hours
    dispatch_source_set_event_handler(timer, ^{
        requestKeyRefresh();
    });
    dispatch_resume(timer);
}


void requestKeyRefresh() {
    // NSLog(@"Requesting key refresh");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int tempSockfd = socket(AF_INET, SOCK_STREAM, 0);
        if (tempSockfd < 0) {
            NSLog(@"Error creating socket for key refresh");
            return;
        }

        struct sockaddr_in serv_addr;
        memset(&serv_addr, 0, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(5006); // Ensure port matches server's listening port
        inet_pton(AF_INET, SERVER_IP, &serv_addr.sin_addr);

        if (connect(tempSockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
            NSLog(@"Error connecting to server");
            close(tempSockfd);
            return;
        }

        const char *refreshMessage = "REFRESH";
        send(tempSockfd, refreshMessage, strlen(refreshMessage), 0);

        // Set socket to non-blocking mode
        int flags = fcntl(tempSockfd, F_GETFL, 0);
        fcntl(tempSockfd, F_SETFL, flags | O_NONBLOCK);

        // Use select() to wait for the socket to become readable
        fd_set readfds;
        FD_ZERO(&readfds);
        FD_SET(tempSockfd, &readfds);
        struct timeval tv;
        tv.tv_sec = 5;  // 5 seconds timeout
        tv.tv_usec = 0;

        int selectResult = select(tempSockfd + 1, &readfds, NULL, NULL, &tv);
        if (selectResult == -1) {
            NSLog(@"Select error");
        } else if (selectResult == 0) {
            NSLog(@"Timeout: No response received within 5 seconds.");
        } else {
            if (FD_ISSET(tempSockfd, &readfds)) {
                char buffer[1024] = {0};
                ssize_t bytesRead = read(tempSockfd, buffer, sizeof(buffer) - 1);
                if (bytesRead > 0) {
                    buffer[bytesRead] = '\0';
                    NSString *encryptedKeyString = [NSString stringWithUTF8String:buffer];
                    NSString *newKey = decryptWithPrivateKey(encryptedKeyString);

                    if (newKey) {
                        if (XOR_KEY) free(XOR_KEY);
                        XOR_KEY = strdup([newKey UTF8String]);

                        [[NSUserDefaults standardUserDefaults] setObject:newKey forKey:@"XORKey"];
                        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"LastKeyRefreshTime"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        NSLog(@"Successfully decrypted and updated the new key: %@", newKey);
                    } else {
                        NSLog(@"Failed to decrypt the new key.");
                    }
                } else {
                    NSLog(@"Failed to read key refresh response or connection closed by server.");
                }
            }
        }

        NSLog(@"Closing temporary socket");
        close(tempSockfd);
    });
}


NSString *decryptWithPrivateKey(NSString *encryptedDataString) {
    NSLog(@"Decrypting with private key");
    // Convert the base64 encoded string to NSData
    NSData *encryptedData = OpenSSLBase64Decode(encryptedDataString);
    
    // Assuming the private key file is named "private_key.pem" and included in the app bundle
    NSBundle *bundle = [[NSBundle alloc] initWithPath:@"/Library/PreferenceBundles/SkyglowNotificationsDaemonPreferences.bundle/Keys"];
    NSString *keyPath = [bundle pathForResource:@"private_key" ofType:@"pem"];
    FILE *keyFile = fopen([keyPath UTF8String], "r");
    if (!keyFile) {
        NSLog(@"Failed to open private key file: %e", errno);
        return nil;
    }
    
    RSA *rsaPrivateKey = PEM_read_RSAPrivateKey(keyFile, NULL, NULL, NULL);
    fclose(keyFile);
    
    if (!rsaPrivateKey) {
        NSLog(@"Failed to read private key.");
        return nil;
    }
    
    int dataSize = RSA_size(rsaPrivateKey);
    unsigned char *decryptedData = (unsigned char *)malloc(dataSize);
    
    // Perform the decryption
    int result = RSA_private_decrypt((int)[encryptedData length], (const unsigned char *)[encryptedData bytes], decryptedData, rsaPrivateKey, RSA_PKCS1_OAEP_PADDING);

    RSA_free(rsaPrivateKey);
    
    if (result == -1) {
        char *error = (char *)malloc(130);
        ERR_load_crypto_strings();
        ERR_error_string(ERR_get_error(), error);
        NSLog(@"Decryption error: %s", error);
        free(error);
        free(decryptedData);
        return nil;
    }
    
    NSData *decryptedNSData = [NSData dataWithBytesNoCopy:decryptedData length:result freeWhenDone:YES];
    NSString *decryptedString = [[NSString alloc] initWithData:decryptedNSData encoding:NSUTF8StringEncoding];
    
    return decryptedString;
}


void checkAndRefreshKeyIfNeeded() {
    NSDate *lastRefreshTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastKeyRefreshTime"];
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"XORKey"];
    
    if (savedKey) {
        XOR_KEY = strdup([savedKey UTF8String]);
    }
    
    if (lastRefreshTime && [[NSDate date] timeIntervalSinceDate:lastRefreshTime] >= 6 * 60 * 60) {
        requestKeyRefresh();
        }
        else if (!savedKey || !lastRefreshTime) {
            requestKeyRefresh();
        } else {
            setupKeyRefreshTimer();
    }
}

NSData *OpenSSLBase64Decode(NSString *base64String) {
    // Convert NSString to C string
    const char *input = [base64String cStringUsingEncoding:NSASCIIStringEncoding];
    size_t length = strlen(input);

    // Set up a memory buffer to hold the decoded data
    BIO *b64 = BIO_new(BIO_f_base64());
    BIO *bio = BIO_new_mem_buf(input, (int)length);
    bio = BIO_push(b64, bio);

    // Do not use newlines to flush buffer
    BIO_set_flags(bio, BIO_FLAGS_BASE64_NO_NL);

    // Decode
    NSMutableData *decodedData = [NSMutableData dataWithLength:length]; // Length is overestimated
    int decodedLength = BIO_read(bio, decodedData.mutableBytes, (int)length);

    [decodedData setLength:decodedLength];

    BIO_free_all(bio);
    return decodedData;
}