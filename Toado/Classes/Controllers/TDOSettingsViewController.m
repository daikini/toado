//
//  TDOSettingsViewController.m
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import "TDOSettingsViewController.h"
#import <Dropbox/Dropbox.h>
#import "TDODataManager.h"

@interface TDOSettingsViewController ()
@property (strong, nonatomic) IBOutlet UISwitch *syncSwitch;
@end

@implementation TDOSettingsViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.syncSwitch.on = [[DBAccountManager sharedManager] linkedAccount] != nil;
}

- (IBAction)doneAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)toggleSyncAction:(id)sender
{
    DBAccountManager *accountManager = [DBAccountManager sharedManager];
    DBAccount *account = [accountManager linkedAccount];

    if ([sender isOn]) {
        if (!account) {
            [accountManager addObserver:self block:^(DBAccount *account) {
                if ([account isLinked]) {
                    [[TDODataManager sharedManager] setSyncEnabled:YES];
                }
            }];
            
            [[DBAccountManager sharedManager] linkFromController:self];
        }
    } else {
        [[TDODataManager sharedManager] setSyncEnabled:NO];
        [account unlink];
    }
}

@end
