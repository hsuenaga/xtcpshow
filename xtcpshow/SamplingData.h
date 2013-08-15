//
//  DataEntry.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/09.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Foundation/Foundation.h>

@interface SamplingData : NSObject<NSCopying>

@property (strong, readonly) NSNumber *number;
@property (strong) NSDate *timestamp;
@property (assign) NSUInteger numberOfSamples;
@property (strong) SamplingData *next;

+ (SamplingData *)dataWithFloat:(float)data;
+ (SamplingData *)dataWithInt:(int)data;
+ (SamplingData *)dataWithFloat:(float)data atDate:(NSDate *)date;
+ (SamplingData *)dataWithInt:(int)data atDate:(NSDate *)date;

- (void)setFloatValue:(float)value;
- (float)floatValue;

- (void)setIntValue:(int)value;
- (int)intValue;

// Pr: NSCopying
- (id)copyWithZone:(NSZone *)zone;

- (void)invalidTimeException;
@end
