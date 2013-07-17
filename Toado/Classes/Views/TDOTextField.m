//
//  TDOTextField.m
//  Toado
//
//  Created by Jonathan Younger on 7/17/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import "TDOTextField.h"

@implementation TDOTextField

- (CGRect)textRectForBounds:(CGRect)bounds
{
    bounds.origin.x += 8.0f;
    return bounds;
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return [self textRectForBounds:bounds];
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return [self textRectForBounds:bounds];
}

@end
