//
//  DataEntry.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/09.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Foundation/Foundation.h>

@interface DataEntry : NSObject

@property (strong, readonly) NSNumber *number;
@property (strong) NSDate *timestamp;
@property (assign) NSUInteger numberOfSamples;
@property (strong) DataEntry *next;

+ (DataEntry *)dataWithFloat:(float)data;
+ (DataEntry *)dataWithInt:(int)data;
+ (DataEntry *)dataWithFloat:(float)data atDate:(NSDate *)date;
+ (DataEntry *)dataWithInt:(int)data atDate:(NSDate *)date;

- (void)setFloatValue:(float)value;
- (float)floatValue;

- (void)setIntValue:(int)value;
- (int)intValue;

- (DataEntry *)copy;

- (void)invalidTimeException;
@end
