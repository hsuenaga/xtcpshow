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

	return self;
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
		date = 0.0;
	}
	else {
		date = tv->tv_sec;
		date = date + ((double)tv->tv_usec / 1000000.0);
	}
	_timestamp = [NSDate dateWithTimeIntervalSince1970:date];
}

- (void)invalidTimeException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Time" reason:@"Invalid Time in DataEntry" userInfo:nil];

	@throw ex;
}
@end
