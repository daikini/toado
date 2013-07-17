//
//  TDOTaskViewController.m
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import "TDOTaskViewController.h"
#import "TDOTag.h"
#import <QuartzCore/QuartzCore.h>

@interface TDOTaskViewController () <UITextViewDelegate>
@property (strong, nonatomic) TDOTask *task;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) IBOutlet UIView *contentView;
@property (strong, nonatomic) IBOutlet UIButton *doneButton;
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) IBOutlet UITextField *tagTextField;
@end

@implementation TDOTaskViewController

- (id)initWithTask:(TDOTask *)task inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self = [super initWithNibName:@"Task" bundle:nil];
    if (self) {
        _task = task;
        _managedObjectContext = managedObjectContext;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.contentView.layer.cornerRadius = 6.0f;
    
    self.tagTextField.layer.cornerRadius = 3.0f;
    self.tagTextField.layer.borderColor = [UIColor colorWithWhite:0.0f alpha:0.2f].CGColor;
    self.tagTextField.layer.borderWidth = 1.0f;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.textView.text = self.task.text;
    [self.textView becomeFirstResponder];
    
    self.tagTextField.text = [[[self.task.tags allObjects] valueForKey:@"name"] componentsJoinedByString:@" "];
    
    [self updateDoneButton];
}

- (IBAction)cancelAction:(id)sender
{
    [self dismissViewControllerWithResult:TDOTaskViewControllerResultCancelled];
}

- (IBAction)doneAction:(id)sender
{
    self.task.text = self.textView.text;
    
    NSMutableSet *tags = [[NSMutableSet alloc] init];
    
    if ([self.tagTextField.text length] > 0) {
        NSArray *tokens = [self.tagTextField.text componentsSeparatedByString:@" "];
        for (NSString *token in tokens) {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Tag"];
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"name ==[cd] %@", token]];
            [fetchRequest setFetchLimit:1];
            
            TDOTag *tag = [[self.managedObjectContext executeFetchRequest:fetchRequest error:nil] lastObject];
            if (!tag) {
                tag = [NSEntityDescription insertNewObjectForEntityForName:@"Tag" inManagedObjectContext:self.managedObjectContext];
                tag.name = token;
            }
        
            [tags addObject:tag];
        }
    }
    
    [self.task setTags:[[NSSet alloc] initWithSet:tags]];
    
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    NSManagedObjectContext *mainManagedObjectContext = [managedObjectContext parentContext];
    
    [managedObjectContext performBlock:^{
        NSError *error = nil;
        if ([managedObjectContext save:&error]) {
            [mainManagedObjectContext save:&error];
        } else {
            NSLog(@"Error saving context: %@", error);
        }
    }];
    
    [self dismissViewControllerWithResult:TDOTaskViewControllerResultDone];
}

- (void)dismissViewControllerWithResult:(TDOTaskViewControllerResult)result
{
    [self.textView resignFirstResponder];
    
    [self willMoveToParentViewController:nil];
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.3f animations:^{
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        strongSelf.view.alpha = 0.0f;
    } completion:^(BOOL finished) {
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        [strongSelf.view removeFromSuperview];
        [strongSelf removeFromParentViewController];
    }];

    if (self.completionHandler) {
        self.completionHandler(result);
    }
}

- (void)updateDoneButton
{
    self.doneButton.enabled = [self.textView.text length] > 0;
}

#pragma mark - UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView
{
    [self updateDoneButton];
}
@end
