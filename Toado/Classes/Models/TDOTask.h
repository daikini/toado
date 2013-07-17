//
//  TDOTask.h
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class TDOTag;

@interface TDOTask : NSManagedObject

@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSNumber * position;
@property (nonatomic, retain) NSSet *tags;

+ (NSUInteger)highestPosition;
@end

@interface TDOTask (CoreDataGeneratedAccessors)

- (void)addTagsObject:(TDOTag *)value;
- (void)removeTagsObject:(TDOTag *)value;
- (void)addTags:(NSSet *)values;
- (void)removeTags:(NSSet *)values;

@end
