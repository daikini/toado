//
//  TDODataManager.m
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import "TDODataManager.h"
#import <ParcelKit/ParcelKit.h>

@interface TDODataManager ()
@property (strong, nonatomic) PKSyncManager *syncManager;
@end

@implementation TDODataManager
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectContext = _managedObjectContext;


+ (instancetype)sharedManager
{
    static dispatch_once_t pred;
    static TDODataManager *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[TDODataManager alloc] init];
    });
    return shared;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) return _managedObjectModel;
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Toado" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) return _persistentStoreCoordinator;
    
    NSURL *applicationDocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [applicationDocumentsDirectory URLByAppendingPathComponent:@"Toado.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:@{NSMigratePersistentStoresAutomaticallyOption:@(YES), NSInferMappingModelAutomaticallyOption:@(YES)} error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) return _managedObjectContext;
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return _managedObjectContext;
}

- (void)setSyncEnabled:(BOOL)enabled
{
    DBAccountManager *accountManager = [DBAccountManager sharedManager];
    
    if (enabled) {
        if (!self.syncManager) {
            DBAccount *account = [accountManager linkedAccount];

            if (account) {
                __weak typeof(self) weakSelf = self;
                [accountManager addObserver:self block:^(DBAccount *account) {
                    typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
                    if (![account isLinked]) {
                        [strongSelf setSyncEnabled:NO];
                        NSLog(@"Unlinked account: %@", account);
                    }
                }];
                
                DBError *dberror = nil;
                DBDatastore *datastore = [DBDatastore openDefaultStoreForAccount:account error:&dberror];
                if (datastore) {
                    self.syncManager = [[PKSyncManager alloc] initWithManagedObjectContext:self.managedObjectContext datastore:datastore];
                    [self.syncManager setTablesForEntityNamesWithDictionary:@{@"Task": @"tasks", @"Tag": @"tags"}];
                    
                    NSError *error = nil;
                    if (![self addMissingSyncAttributeValueToCoreDataObjects:&error]) {
                       NSLog(@"Error adding missing sync attribute value to Core Data objects: %@", error); 
                    } else if ([[datastore getTables:nil] count] == 0) {
                        if (![self updateDropboxFromCoreData:&error]) {
                            NSLog(@"Error updating Dropbox from Core Data: %@", error);
                        }
                    }
                } else {
                    NSLog(@"Error opening default datastore: %@", dberror);
                }
            }
        }
        
        [self.syncManager startObserving];
    } else {
        [self.syncManager stopObserving];
        self.syncManager = nil;
        
        [accountManager removeObserver:self];
    }
}

- (BOOL)addMissingSyncAttributeValueToCoreDataObjects:(NSError **)error
{
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    [managedObjectContext setUndoManager:nil];

    NSString *syncAttributeName = self.syncManager.syncAttributeName;
    NSArray *entityNames = [self.syncManager entityNames];
    for (NSString *entityName in entityNames) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%K == nil", syncAttributeName]];
        [fetchRequest setFetchBatchSize:25];
        
        NSArray *objects = [managedObjectContext executeFetchRequest:fetchRequest error:error];
        if (objects) {
            for (NSManagedObject *managedObject in objects) {
                if (![managedObject valueForKey:syncAttributeName]) {
                    [managedObject setValue:[PKSyncManager syncID] forKey:syncAttributeName];
                }
            }
        } else {
            return NO;
        }
    }
    
    if ([managedObjectContext hasChanges]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncManagedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:managedObjectContext];
        BOOL saved = [managedObjectContext save:error];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:managedObjectContext];
        return saved;
    }
    
    return YES;
}

- (BOOL)updateDropboxFromCoreData:(NSError **)error
{
    __block BOOL result = YES;
    NSManagedObjectContext *managedObjectContext = self.syncManager.managedObjectContext;
    DBDatastore *datastore = self.syncManager.datastore;
    NSString *syncAttributeName = self.syncManager.syncAttributeName;
    
    NSDictionary *tablesByEntityName = [self.syncManager tablesByEntityName];
    [tablesByEntityName enumerateKeysAndObjectsUsingBlock:^(NSString *entityName, NSString *tableId, BOOL *stop) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
        [fetchRequest setFetchBatchSize:25];
        
        NSArray *managedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:error];
        if (managedObjects) {
            for (NSManagedObject *managedObject in managedObjects) {
                DBTable *table = [datastore getTable:tableId];
                DBError *dberror = nil;
                DBRecord *record = [table getOrInsertRecord:[managedObject valueForKey:syncAttributeName] fields:nil inserted:NULL error:&dberror];
                if (record) {
                    [record pk_setFieldsWithManagedObject:managedObject syncAttributeName:syncAttributeName];
                } else {
                    if (error) {
                        *error = [NSError errorWithDomain:[dberror domain] code:[dberror code] userInfo:[dberror userInfo]];
                    }
                    result = NO;
                    *stop = YES;
                }
            }
        } else {
            *stop = YES;
        }
    }];
    
    if (result) {        
        DBError *dberror = nil;
        if ([datastore sync:&dberror]) {
            return YES;
        } else {
            if (error) *error = [NSError errorWithDomain:[dberror domain] code:[dberror code] userInfo:[dberror userInfo]];
            return NO;
        }
    } else {
        return NO;
    }
}

- (void)syncManagedObjectContextDidSave:(NSNotification *)notification
{
    [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
}
@end
