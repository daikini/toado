//
//  TDOTask.m
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import "TDOTask.h"
#import "TDOTag.h"
#import "TDODataManager.h"

@implementation TDOTask

@dynamic text;
@dynamic position;
@dynamic tags;

+ (NSUInteger)highestPosition
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Task"];
    [fetchRequest setFetchLimit:1];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"position" ascending:NO]]];
    TDOTask *task = [[[TDODataManager sharedManager].managedObjectContext executeFetchRequest:fetchRequest error:nil] lastObject];
    return [task.position unsignedIntegerValue];
}
@end
