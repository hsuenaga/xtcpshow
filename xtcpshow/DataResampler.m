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

- (void)purgeData
{
	write_protect = FALSE;
	_data = nil;
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
	[_data replaceValueUsingBlock:^(float *value, NSUInteger idx, BOOL *stop) {
		(*value) = (*value) * scale;
	}];
}


- (void)discreteScaleQueue:(float)scale
{
	DataQueue *dst = [[DataQueue alloc] init];
	__block NSUInteger dst_idx, sample_count;
	__block float newvalue;

	sample_count = 0;
	newvalue = 0.0;
	dst_idx = 0;
	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		float f_idx;

		newvalue += value;
		sample_count++;

		f_idx = (float)idx * scale;
		while (dst_idx < (NSUInteger)floor(f_idx)) {
			DataEntry *entry =
			[DataEntry dataWithFloat:newvalue atTimeval:NULL];
			[entry setNumberOfSamples:sample_count];
			[dst addDataEntry:entry];
			newvalue = 0.0;
			sample_count = 0;
			dst_idx++;
		}
	}];
	write_protect = FALSE;
	_data = dst;
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

- (void)linearScaleQueue:(float)scale
{
	if (scale < 1.0)
		[self linearDownSamplingQueue:scale];
	else
		[self linearUpSamplingQueue:scale];
}

- (void)linearUpSamplingQueue:(float)scale
{
	DataQueue *dst = [[DataQueue alloc] init];
	NSUInteger dst_idx, dst_samples;
	float src0, src1;
	NSUInteger src0_idx;

	[self makeMutable];

	dst_samples = (float)[_data count];
	dst_samples = (NSUInteger)(ceil((float)dst_samples * scale));

	src0 = [_data dequeueFloatValue];
	src1 = [_data dequeueFloatValue];
	src0_idx = 0;
	for (dst_idx = 0; dst_idx < dst_samples; dst_idx++) {
		NSUInteger pivot_idx;
		float pivot = (float)dst_idx / scale;
		float value;

		pivot_idx = (NSUInteger)(floor(pivot));
		while (pivot_idx > src0_idx) {
			/* get left side and right side value */
			src0 = src1;
			src1 = [_data dequeueFloatValue];
			src0_idx++;
		}
		if (isnan(src0) || isnan(src1))
			break;

		value = src0 * (ceil(pivot) - pivot);
		value += src1 * (pivot - floor(pivot));
		[dst addFloatValue:value];
	}
	_data = dst;
}

- (void)linearDownSamplingQueue:(float)scale
{
	DataQueue *dst = [[DataQueue alloc] init];
	__block NSUInteger dst0_idx;
	__block float dst0, dst1;

	dst0_idx = 0;
	dst0 = dst1 = 0.0;
	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		NSUInteger pivot_idx;
		float pivot;

		pivot = (float)idx * scale;
		pivot_idx = (NSUInteger)(floor(pivot));
		while (dst0_idx < pivot_idx) {
			[dst addFloatValue:dst0];
			dst0 = dst1;
			dst1 = 0.0;
			dst0_idx++;
		}
		dst0 += value * (ceil(pivot) - pivot);
		dst1 += value * (pivot - floor(pivot));
	}];
	[dst addFloatValue:dst0];

	_data = dst;
}

//
// clip head(older sample) of queue
//
//
//           |<--location-->|
//  original |------------------------------------|
//
//       new                |------------|
//
//                          |<--length-->|
//
- (void)clipQueueHead:(NSRange)range
{
	[self makeMutable];
	if (range.location != 0)
		[_data removeFromHead:range.location];
	if (range.length != 0)
		[_data clipFromHead:range.length];
}

//
// clip tail(= newer sample) of queue
//
//                                   |<--location-->|
//  original |--------------------------------------|
//
//       new            |------------|
//
//                      |<--length-->|
//
- (void)clipQueueTail:(NSRange)range
{
	NSRange reverse = range;

	[self makeMutable];

	if ([_data count] < (range.location + range.length)) {
		NSUInteger under_flow;
		under_flow = (range.location + range.length) - [_data count];

		while (under_flow-- > 0)
			[_data prependFloatValue:0.0];
	}
	reverse.location = [_data count] - range.location;
	reverse.location -= range.length;
	[self clipQueueHead:reverse];
}

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

- (void)movingAverage:(NSUInteger)samples
{
	DataQueue *dst, *sma;

	dst = [[DataQueue alloc] init];

	sma = [[DataQueue alloc] init];
	[sma zeroFill:samples];

	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		[sma shiftFloatValueWithNewValue:value];
		[dst addFloatValue:[sma averageFloatValue]];
	}];

	write_protect = FALSE;
	_data = dst;
}

- (void)triangleMovingAverage:(NSUInteger)samples
{
	DataQueue *dst, *sma1, *sma2;
	NSUInteger half_samples;

	half_samples = samples / 2 + 1;

	dst = [[DataQueue alloc] init];

	sma1 = [[DataQueue alloc] init];
	[sma1 zeroFill:half_samples];

	sma2 = [[DataQueue alloc] init];
	[sma2 zeroFill:half_samples];

	[_data enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		DataEntry *new_data;

		[sma1 shiftFloatValueWithNewValue:[data floatValue]];
		[sma2 shiftFloatValueWithNewValue:[sma1 averageFloatValue]];
		new_data = [DataEntry dataWithFloat:[sma2 averageFloatValue] atDate:[data timestamp]];
		[new_data setNumberOfSamples:[data numberOfSamples]];

		[dst addDataEntry:new_data];
	}];

	write_protect = FALSE;
	_data = dst;
}

- (void)invalidValueException
{
	NSException *ex;

	ex = [NSException exceptionWithName:@"Invalid value" reason:@"Invalid value in DataResampler" userInfo:nil];

	@throw ex;
}
@end
