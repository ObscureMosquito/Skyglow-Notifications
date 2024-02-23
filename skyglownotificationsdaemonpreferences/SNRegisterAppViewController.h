#import <UIKit/UIKit.h>

@interface AppsListRegisterViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) NSArray *sortedDisplayIdentifiers; // Array to hold sorted app identifiers
@property (strong, nonatomic) NSDictionary *applications; // Dictionary to hold app names and identifiers

@end

NSString *bundleID;