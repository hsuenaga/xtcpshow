//
//  DataResampler.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "DataResampler.h"

#undef AVERAGE_SCALING

@implementation DataResampler
- (void)importData:(DataQueue *)data
{
	original = data;
	_data = data;
}

- (void)purgeData
{
	original = nil;
	_data = nil;
}

- (void)scaleQueue:(float)scale
{
	DataQueue *dst;
	DataQueue *filter;
	__block NSUInteger last_idx = 0;
	__block NSUInteger last_pkts = 0;
	__block float last_sum = 0.0;
	__block float last_max = 0.0, max = 0.0;
	
	dst = [[DataQueue alloc] init];
	filter = [[DataQueue alloc] init];
	[filter zeroFill:2];

	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		NSUInteger dst_idx;
		NSUInteger advanced;
		float f_idx;
		
		f_idx = (float)idx * scale;
		dst_idx = (NSUInteger)(floor(f_idx));
		advanced = dst_idx - last_idx;

		if (last_max < value)
			last_max = value;
		if (max < value)
			max = value;
		last_sum += value;
		last_pkts++;
		[filter shiftFloatValueWithNewValue:value];
		
		if (advanced > 0) {
			float newval;
			
			// select next value
#ifdef AVERAGE_SCALING
			newval = last_sum / (float)last_pkts;
#else
			newval = [filter averageFloatValue];
#endif
			[dst addFloatValue:newval];

			// store new value.
			while (advanced--) {
				[dst addFloatValue:newval];
				newval = 0.0;
			}
			last_max = 0.0;
			last_sum = 0.0;
			last_pkts = 0;
		}
		last_idx = dst_idx;
	}];

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
	DataQueue *dst;
	__block NSUInteger length = range.length;
	
	dst = [[DataQueue alloc] init];
	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		if (idx < range.location)
			return;
		if (length-- == 0) {
			*stop = TRUE;
			return;
		}
		[dst addFloatValue:value];
	}];
	
	_data = dst;
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
	
	if ([self.data count] < (range.location + range.length)) {
		if (range.location > [self.data count])
			return;
		range.length = [self.data count] - range.location;
	}
	reverse.location = [self.data count] - range.length;
	reverse.location -= range.location;
	
	[self clipQueueHead:reverse];
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

	_data = dst;
}

@end
