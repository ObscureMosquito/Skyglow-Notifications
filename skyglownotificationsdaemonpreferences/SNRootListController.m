#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SNRootListController.h"

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

/*
- (void)takeToGuide {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Skyglow Notifications" message:@"This will take you to a guide I haven't made in the future, imagine how cool it would be if it worked though." preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}*/

@end
