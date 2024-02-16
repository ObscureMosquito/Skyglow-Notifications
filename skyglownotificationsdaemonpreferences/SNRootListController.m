#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SNRootListController.h"
#import "SNGuideViewController.h"

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

- (void)showGuide {
    GuideViewController *guideVC = [[GuideViewController alloc] init];
    [self.navigationController pushViewController:guideVC animated:YES];
}

@end
