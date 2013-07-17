//
//  TDOTaskViewController.h
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TDOTask.h"

typedef NS_ENUM(NSInteger, TDOTaskViewControllerResult) {
    TDOTaskViewControllerResultCancelled,
    TDOTaskViewControllerResultDone
};

typedef void (^TDOTaskViewControllerrCompletionHandler)(TDOTaskViewControllerResult result);

@interface TDOTaskViewController : UIViewController
@property (copy, nonatomic) TDOTaskViewControllerrCompletionHandler completionHandler;

- (id)initWithTask:(TDOTask *)task inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;
@end
