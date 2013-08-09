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
	_timestamp.tv_sec = 0;
	_timestamp.tv_usec = 0;
	_next = nil;

	return self;
}

+ (DataEntry *)dataWithFloat:(float)data atTime:(struct timeval *)time
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setFloatValue:data];
	[new setTimeval:time];
	return new;
}

+ (DataEntry *)dataWithFloat:(float)data atSeconds:(float)seconds
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setFloatValue:data];
	[new setFloatTime:seconds];
	return new;
}

+ (DataEntry *)dataWithInt:(int)data atTime:(struct timeval *)time
{
	DataEntry *new = [[DataEntry alloc] init];

	[new setIntValue:data];
	[new setTimeval:time];

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
	if (tv) {
		_timestamp.tv_sec = tv->tv_sec;
		_timestamp.tv_usec = tv->tv_usec;
	}
	else {
		_timestamp.tv_sec = 0;
		_timestamp.tv_usec = 0;
	}
}

- (void)setFloatTime:(float)value
{
	struct timeval tv;

	if (value < 0.0f)
		[self invalidTimeException];

	tv.tv_sec = (int)(floor(value));
	tv.tv_usec = (int)((value - floor(value)) * 1000000.0f);
	[self setTimeval:&tv];
}

- (float)floatTime
{
	float time_second;

	time_second = (float)(_timestamp.tv_usec / 1000000.0f);
	time_second += (float)(_timestamp.tv_sec);

	return time_second;
}

- (void)invalidTimeException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Time" reason:@"Invalid Time in DataEntry" userInfo:nil];

	@throw ex;
}
@end
