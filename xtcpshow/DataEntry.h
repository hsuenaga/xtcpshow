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
@property (assign, readonly) struct timeval timestamp;
@property (strong) DataEntry *next;

+ (DataEntry *)dataWithFloat:(float)data atTime:(struct timeval *)time;
+ (DataEntry *)dataWithFloat:(float)data atSeconds:(float)seconds;
+ (DataEntry *)dataWithInt:(int)data atTime:(struct timeval *)time;

- (void)setFloatValue:(float)value;
- (float)floatValue;

- (void)setIntValue:(int)value;
- (int)intValue;

- (void)setTimeval:(struct timeval *)tv;
- (void)setFloatTime:(float)value;
- (float)floatTime; // [sec]

- (void)invalidTimeException;
@end
