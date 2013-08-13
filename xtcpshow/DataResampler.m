//
//  DataResampler.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "DataResampler.h"
#import "DataEntry.h"

@implementation DataResampler
- (void)importData:(DataQueue *)data
{
	write_protect = TRUE;
	_data = data;
}

- (void)makeMutable
{
	DataQueue *dst = [[DataQueue alloc] init];

	if (!write_protect)
		return;
	if (_data == nil)
		return;

	[_data enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		[dst addDataEntry:[data copy]];
	}];

	write_protect = FALSE;
	_data = dst;
}

- (void)scaleAllValue:(float)scale
{
	if (isnan(scale))
		[self invalidValueException];
	if (isinf(scale))
		[self invalidValueException];

	if ([_data isEmpty]) {
		NSLog(@"data is empty");
		return;
	}
	[_data enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		[data setFloatValue:([data floatValue] * scale)];
	}];
}

- (void)alignWithTick:(NSTimeInterval)tick fromDate:(NSDate *)start toDate:(NSDate *)end
{
	DataQueue *dst = [[DataQueue alloc] init];
	NSTimeInterval unix_time;
	NSDate *slot;
	float slot_value, remain;

	[self makeMutable];
	
	// round up start/end
	unix_time = [start timeIntervalSince1970];
	start = [NSDate dateWithTimeIntervalSince1970:(floor(unix_time/tick) * tick)];
	unix_time = [end timeIntervalSince1970];
	end = [NSDate dateWithTimeIntervalSince1970:(ceil(unix_time/tick) * tick)];
	
	slot = start;

	while ([[_data firstDate] laterDate:start] == start)
		[_data dequeueDataEntry];

	slot_value = remain = 0.0f;
	while ([slot laterDate:end] == end) {
		DataEntry *sample;
		NSUInteger sample_count = 0;

		while ([[_data firstDate] laterDate:slot] == slot) {
			DataEntry *source;
			float value, new_value;

			source = [_data dequeueDataEntry];
			value = [source floatValue];
			value = value + remain;

			new_value = slot_value + value;
			remain = (new_value - slot_value) - value;
			slot_value = new_value;
			sample_count += [source numberOfSamples];
		}
		sample = [DataEntry dataWithFloat:slot_value atDate:slot];
		[sample setNumberOfSamples:sample_count];
		[dst addDataEntry:sample];

		slot = [slot dateByAddingTimeInterval:tick];
		slot_value = remain = 0.0f;
	}
	_data = dst;
}

//
// get Queue Data after start. (don't include start)
//
- (void)clipQueueFromDate:(NSDate *)start;
{
	DataQueue *dst = [[DataQueue alloc] init];

	[_data enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		if ([[data timestamp] earlierDate:start] != start)
			return;

		[dst addDataEntry:[data copy]];
	}];

	write_protect = FALSE;
	_data = dst;
}

- (void)triangleMovingAverage:(NSUInteger)samples
{
	DataQueue *dst, *sma1, *sma2;
	NSUInteger half_samples;

	[self makeMutable];

	half_samples = samples / 2 + 1;

	dst = [[DataQueue alloc] init];

	sma1 = [[DataQueue alloc] init];
	[sma1 zeroFill:half_samples];

	sma2 = [[DataQueue alloc] init];
	[sma2 zeroFill:half_samples];

	[_data enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		[sma1 shiftDataWithNewData:[data copy]];
		[sma2 shiftDataWithNewData:[DataEntry dataWithFloat:[sma1 averageFloatValue]]];
		[data setFloatValue:[sma2 averageFloatValue]];
	}];
}

- (void)invalidValueException
{
	NSException *ex;

	ex = [NSException exceptionWithName:@"Invalid value" reason:@"Invalid value in DataResampler" userInfo:nil];

	@throw ex;
}
@end
