//
//  TDOTaskListViewController.m
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import "TDOTaskListViewController.h"
#import "TDODataManager.h"
#import "TDOTask.h"
#import "TDOTaskCell.h"
#import "TDOTaskViewController.h"

@interface TDOTaskListViewController () <UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate>
@property (strong, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@end

@implementation TDOTaskListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.fetchedResultsController performFetch:nil];
    [self.tableView reloadData];
}

- (IBAction)addAction:(id)sender
{
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [managedObjectContext setParentContext:[TDODataManager sharedManager].managedObjectContext];
    TDOTask *task = [NSEntityDescription insertNewObjectForEntityForName:@"Task" inManagedObjectContext:managedObjectContext];
    task.position = @([TDOTask highestPosition] + 1);
    [self presentTask:task inManagedObjectContext:managedObjectContext];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (!_fetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Task"];
        [fetchRequest setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"position" ascending:YES]]];
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[TDODataManager sharedManager].managedObjectContext sectionNameKeyPath:nil cacheName:nil];
        _fetchedResultsController.delegate = self;
    }
    return _fetchedResultsController;
}

- (void)presentTask:(TDOTask *)task inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    UIColor *tintColor = self.navigationBar.tintColor;
    self.navigationBar.tintColor = [UIColor lightGrayColor];
    
    TDOTaskViewController *taskViewController = [[TDOTaskViewController alloc] initWithTask:task inManagedObjectContext:managedObjectContext];
    __weak typeof(self) weakSelf = self;
    taskViewController.completionHandler = ^(TDOTaskViewControllerResult result) {
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        strongSelf.navigationBar.tintColor = tintColor;
    };
    [taskViewController willMoveToParentViewController:self];
    taskViewController.view.alpha = 0.0f;
    [self.view addSubview:taskViewController.view];

    [UIView animateWithDuration:0.3f animations:^{
        taskViewController.view.alpha = 1.0f;
    } completion:^(BOOL finished) {
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        [strongSelf addChildViewController:taskViewController];
    }];
}

- (void)configureCell:(TDOTaskCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    TDOTask *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.task = task;
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[self.fetchedResultsController sections] objectAtIndex:section] numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TDOTaskCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TaskCell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
        NSManagedObjectContext *managedObjectContext = [TDODataManager sharedManager].managedObjectContext;
        [managedObjectContext deleteObject:managedObject];
        [managedObjectContext save:nil];
        
        [self.fetchedResultsController performFetch:nil];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [managedObjectContext setParentContext:[TDODataManager sharedManager].managedObjectContext];
    TDOTask *task = (TDOTask *)[managedObjectContext objectWithID:[[self.fetchedResultsController objectAtIndexPath:indexPath] objectID]];
    [self presentTask:task inManagedObjectContext:managedObjectContext];
}

#pragma mark - NSFetchedResultsControllerDelegate
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    UITableView *tableView = self.tableView;
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    
    UITableView *tableView = self.tableView;
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:(TDOTaskCell *)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

@end
