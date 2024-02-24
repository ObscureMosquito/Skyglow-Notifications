#import <UIKit/UIKit.h>

@interface AppsListUnregisterViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) NSArray *sortedDisplayIdentifiers;
@property (strong, nonatomic) NSDictionary *applications;

@end

NSString *bundleID;