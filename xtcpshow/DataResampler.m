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
	write_protect = TRUE;
	_data = data;
}

- (void)makeMutable
{
	DataQueue *dst;
	
	if (!write_protect)
		return;
	if (_data == nil)
		return;
	
	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		[dst addFloatValue:value];
	}];
	write_protect = FALSE;
	_data = dst;
}

- (void)purgeData
{
	write_protect = FALSE;
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
	
	write_protect = FALSE;
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
	
	write_protect = FALSE;
	_data = dst;
}

@end
