//
//  SamplingData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/09.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "SamplingData.h"

@implementation SamplingData
+ (id)dataWithoutSample
{
	SamplingData *new = [[[self class] alloc] init];
	new->_timestamp = [NSDate date];

	return new;
}

+ (id)dataWithSingleFloat:(float)data
{
	SamplingData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithFloat:data];
	new->_timestamp = [NSDate date];
	new->_numberOfSamples = 1;

	return new;
}

+ (id)dataWithSingleInt:(int)data
{
	SamplingData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithInt:data];
	new->_timestamp = [NSDate date];
	new->_numberOfSamples = 1;

	return new;
}

+ (id)dataWithFloat:(float)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples;
{
	SamplingData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithFloat:data];
	new->_timestamp = [date copy];
	new->_numberOfSamples = samples;

	return new;
}

+ (id)dataWithInt:(int)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
	SamplingData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithInt:data];
	new->_timestamp = date;
	new->_numberOfSamples = samples;

	return new;
}

+ (id)dataWithNumber:(NSNumber *)number atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
	SamplingData *new = [[[self class] alloc] init];

	new->_number = number;
	new->_timestamp = date;
	new->_numberOfSamples = samples;

	return new;
}

- (float)floatValue
{
	return [_number floatValue];
}

- (int)intValue
{
	return [_number intValue];
}

- (id)copyWithZone:(NSZone *)zone
{
	SamplingData *new = [[SamplingData alloc] init];

	new->_number = [_number copy];
	new->_timestamp = [_timestamp copy];
	new->_numberOfSamples = _numberOfSamples;

	return new;
}

- (void)invalidTimeException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Time" reason:@"Invalid Time in DataEntry" userInfo:nil];

	@throw ex;
}
@end
