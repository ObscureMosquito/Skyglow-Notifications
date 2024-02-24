#import "SNUnregisterAppViewController.h"
#import "SettingsUtilities.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <AppList/AppList.h>

@implementation AppsListUnregisterViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    
    [self loadInstalledApps];
}


- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}


- (void)loadInstalledApps {
    // Fetching applications using AppList
    self.applications = [[ALApplicationList sharedApplicationList] applications];
    self.sortedDisplayIdentifiers = [[self.applications allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSString *first = self.applications[obj1];
        NSString *second = self.applications[obj2];
        return [first compare:second];
    }];
    
    // Filter out apps with "com.apple" prefix
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (SELF BEGINSWITH %@)", @"com.apple"];
    self.sortedDisplayIdentifiers = [self.sortedDisplayIdentifiers filteredArrayUsingPredicate:predicate];
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sortedDisplayIdentifiers.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"AppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    NSString *displayIdentifier = self.sortedDisplayIdentifiers[indexPath.row];
    NSString *appName = self.applications[displayIdentifier];
    cell.textLabel.text = appName;
    
    // Fetch and set the app icon
    UIImage *icon = [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:displayIdentifier];
    cell.imageView.image = icon;
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *selectedAppIdentifier = self.sortedDisplayIdentifiers[indexPath.row];
    [self checkIfTweakIsDisabledForAppIdentifier:selectedAppIdentifier];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (void)checkIfTweakIsDisabledForAppIdentifier:(NSString *)appIdentifier {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    BOOL isEnabled = [[prefs objectForKey:@"enabled"] boolValue];
    if (isEnabled) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Skyglow Notifications" 
                                                        message:@"You can only register an application when the tweak is disabled, would you like to disable it and restart springboard? (You will need to come back here and register the application)" 
                                                       delegate:self 
                                              cancelButtonTitle:@"Respring" 
                                              otherButtonTitles:@"Cancel", nil];
        [alert show];
    } else {
        [self unregisterApplication:appIdentifier];
    }
}


- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSLog(@"Button index: %ld", (long)buttonIndex);
    if (buttonIndex == 0) {
        NSLog(@"Disabling tweak and restarting springboard");
        NSDictionary *prefs = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"] mutableCopy];
        [prefs setValue:@NO forKey:@"enabled"];
        [[NSUserDefaults standardUserDefaults] setPersistentDomain:prefs forName:@"com.skyglow.sndp"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        system("killall -9 SpringBoard");
    }
}


- (void)unregisterApplication:(NSString *)bundleIdentifier {
    NSLog(@"Unregistering application: %@", bundleIdentifier);
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.skyglow.sndp"];
    NSMutableDictionary *mutablePrefs = [prefs mutableCopy];
    [mutablePrefs setValue:bundleIdentifier forKey:@"lastUnregisteredApp"];
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:mutablePrefs forName:@"com.skyglow.sndp"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.Skyglow.Notifications.unregister"), NULL, NULL, true);
}



@end