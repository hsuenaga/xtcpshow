//
//  DataEntry.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/09.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "SamplingData.h"

@implementation SamplingData
+ (SamplingData *)dataWithFloat:(float)data
{
	SamplingData *new = [[SamplingData alloc] init];

	new->_number = [NSNumber numberWithFloat:data];

	return new;
}

+ (SamplingData *)dataWithInt:(int)data
{
	SamplingData *new = [[SamplingData alloc] init];

	new->_number = [NSNumber numberWithInt:data];

	return new;
}

+ (SamplingData *)dataWithFloat:(float)data atDate:(NSDate *)date
{
	SamplingData *new = [[SamplingData alloc] init];

	new->_number = [NSNumber numberWithFloat:data];
	new->_timestamp = date;

	return new;
}

+ (SamplingData *)dataWithInt:(int)data atDate:(NSDate *)date
{
	SamplingData *new = [[SamplingData alloc] init];

	new->_number = [NSNumber numberWithInt:data];
	new->_timestamp = date;

	return new;
}

- (void)setFloatValue:(float)value
{
	_number = [NSNumber numberWithFloat:value];
}

- (float)floatValue
{
	return [_number floatValue];
}

- (void)setIntValue:(int)value
{
	_number = [NSNumber numberWithInt:value];
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
	new->_next = nil;

	return new;
}

- (void)invalidTimeException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Time" reason:@"Invalid Time in DataEntry" userInfo:nil];

	@throw ex;
}
@end
