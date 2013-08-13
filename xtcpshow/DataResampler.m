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
//
// protected:
//
- (DataQueue *)copyQueue:(DataQueue *)source FromDate:(NSDate *)start;
{
	DataQueue *dst = [[DataQueue alloc] init];

	[source enumerateDataUsingBlock:^(DataEntry *data, NSUInteger idx, BOOL *stop) {
		if ([[data timestamp] earlierDate:start] != start)
			return;

		[dst addDataEntry:[data copy]];
	}];

	return dst;
}

- (void)invalidValueException
{
	NSException *ex;

	ex = [NSException exceptionWithName:@"Invalid value" reason:@"Invalid value in DataResampler" userInfo:nil];

	@throw ex;
}

//
// public:
//
- (void)purgeData
{
	_data = nil;
}

- (void)resampleData:(DataQueue *)input
{
	NSTimeInterval dataLength, unix_time;
	NSDate *start, *end;
	NSUInteger MASamples, maxSamples;
	DataQueue *delta;
	float bytes2mbps, tick;

	// convert units
	tick = _outputTimeLength / _outputSamples; // [sec/sample]
	MASamples = ceil(_MATimeLength / tick);
	maxSamples = _outputSamples + MASamples;
	bytes2mbps = 8.0f / tick; // [bps]
	bytes2mbps = bytes2mbps / 1000.0f / 1000.0f; // [Mbps]

	// allocate data if need
	if (_data == nil) {
		NSUInteger TMASamples = MASamples / 2;

		_data = [[DataQueue alloc] init];
		sma[0] = [[DataQueue alloc] init];
		sma[1] = [[DataQueue alloc] init];
		[sma[0] zeroFill:TMASamples];
		[sma[1] zeroFill:TMASamples];
	}

	// get range of time
	dataLength = -(_outputTimeLength + _MATimeLength);
	end = [input last_update];
	start = [end dateByAddingTimeInterval:dataLength];
	if ([_data count] != 0)
		start = [start laterDate:[_data lastDate]];

	// round start/end
	unix_time = [start timeIntervalSince1970];
	unix_time = floor(unix_time/tick) * tick;
	start = [NSDate dateWithTimeIntervalSince1970:unix_time];
	unix_time = [end timeIntervalSince1970];
	unix_time = ceil(unix_time/tick) * tick;
	end = [NSDate dateWithTimeIntervalSince1970:unix_time];

	// clip updated data only
	delta = [self copyQueue:input FromDate:start];
	if (!delta || [delta count] == 0)
		return;

	// filter
	for (NSDate *slot = start;
	     [slot laterDate:end] == end;
	     slot = [slot dateByAddingTimeInterval:tick]) {
		DataEntry *sample;
		NSUInteger sample_count = 0;
		float slot_value = 0.0f, remain = 0.0f;

		// Step1: folding(sum) source data before slot
		while ([[delta firstDate] laterDate:slot] == slot) {
			DataEntry *source;
			float value, new_value;

			source = [delta dequeueDataEntry];
			value = [source floatValue] + remain;
			new_value = slot_value + value;
			remain = (new_value - slot_value) - value;
			slot_value = new_value;

			sample_count += [source numberOfSamples];
		}
		sample = [DataEntry dataWithFloat:slot_value];

		// Step2: MA filter
		if (MASamples > 2) {
			sample = [sma[0] shiftDataWithNewData:sample];
			[sample setFloatValue:[sma[0] averageFloatValue]];
			sample = [sma[1] shiftDataWithNewData:sample];
			[sample setFloatValue:[sma[1] averageFloatValue]];
		}

		// Step3: convert unit of sample
		[sample setFloatValue:([sample floatValue] * bytes2mbps)];

		// finalize and output sample
		[sample setNumberOfSamples:sample_count];
		[sample setTimestamp:slot];
		[_data addDataEntry:sample withLimit:maxSamples];
	}

	// get additional data(noise) generated by filter
	_overSample = [_data count] - _outputSamples;
}
@end
