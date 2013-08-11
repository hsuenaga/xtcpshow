//
//  DataEntry.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/09.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "DataEntry.h"

@implementation DataEntry
- (DataEntry *)init
{
	self = [super init];

	_number = nil;
	_timestamp = nil;
	_next = nil;
	_numberOfSamples = 0;

	return self;
}

+ (DataEntry *)dataWithFloat:(float)data
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setFloatValue:data];
	
	return new;
}

+ (DataEntry *)dataWithFloat:(float)data atTimeval:(struct timeval *)time
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setFloatValue:data];
	[new setTimeval:time];

	return new;
}

+ (DataEntry *)dataWithFloat:(float)data atDate:(NSDate *)date
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setFloatValue:data];
	new.timestamp = date;

	return new;
}

+ (DataEntry *)dataWithInt:(int)data atTimeval:(struct timeval *)time
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setIntValue:data];
	[new setTimeval:time];

	return new;
}

+ (DataEntry *)dataWIthInt:(int)data atDate:(NSDate *)date
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setIntValue:data];
	new.timestamp = date;

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

- (void)setTimeval:(struct timeval *)tv
{
	NSTimeInterval date;

	if (tv == NULL) {
		_timestamp = nil;
		return;
	}

	date = tv->tv_sec;
	date = date + ((double)tv->tv_usec / 1000000.0);
	_timestamp = [NSDate dateWithTimeIntervalSince1970:date];
}

- (DataEntry *)copy
{
	DataEntry *new = [[DataEntry alloc] init];

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
