//
//  SamplingData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/09.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/queue.h>
#import <Foundation/Foundation.h>

@interface SamplingData : NSObject<NSCopying> {
	NSNumber *_number;
}
@property (strong, readonly) NSDate *timestamp;
@property (assign, readonly) NSUInteger numberOfSamples;

+ (id)dataWithoutSample;
+ (id)dataWithSingleFloat:(float)data;
+ (id)dataWithSingleInt:(int)data;
+ (id)dataWithFloat:(float)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples;
+ (id)dataWithInt:(int)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples;
+ (id)dataWithNumber:(NSNumber *)number atDate:(NSDate *)date fromSamples:(NSUInteger)samples;

- (float)floatValue;
- (int)intValue;

// Pr: NSCopying
- (id)copyWithZone:(NSZone *)zone;

- (void)invalidTimeException;
@end
