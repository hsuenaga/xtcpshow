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
	DataQueue *dst = [[DataQueue alloc] init];
	
	if (!write_protect)
		return;
	if (_data == nil)
		return;
    
    [dst setInterval:[_data interval]];
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

- (void)scaleAllValue:(float)scale
{
    if (isnan(scale))
        return;
    if (isinf(scale))
        return;
    if ([_data isEmpty])
        return;
    [_data replaceValueUsingBlock:^(float *value, NSUInteger idx, BOOL *stop) {
        (*value) = (*value) * scale;
    }];
}

- (void)discreteScaleQueue:(float)scale
{
    DataQueue *dst = [[DataQueue alloc] init];
    __block NSUInteger dst_idx;
    __block float newvalue;

    [dst setInterval:([_data interval] * scale)];
    newvalue = 0.0;
    dst_idx = 0;
    [_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
        float f_idx;
        
        newvalue += value;
        
        f_idx = (float)idx * scale;
        while (dst_idx < (NSUInteger)floor(f_idx)) {
            [dst addFloatValue:newvalue];
            newvalue = 0.0;
            dst_idx++;
        }
    }];
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
    [dst setInterval:([_data interval] * scale)];

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
		
		value = src0 * (pivot - floor(pivot));
		value += src1 * (ceil(pivot) - pivot);
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
    [dst setInterval:([_data interval] * scale)];
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
		dst0 += value * (pivot - floor(pivot));
		dst1 += value * (ceil(pivot) - pivot);
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

- (void)movingAverage:(NSUInteger)samples
{
	DataQueue *dst, *sma;

	dst = [[DataQueue alloc] init];
	sma = [[DataQueue alloc] init];
	[sma zeroFill:samples];
    
    [dst setInterval:[_data interval]];
    [sma setInterval:[_data interval]];

	[_data enumerateFloatUsingBlock:^(float value, NSUInteger idx, BOOL *stop) {
		[sma shiftFloatValueWithNewValue:value];
		[dst addFloatValue:[sma averageFloatValue]];
	}];
	
	write_protect = FALSE;
	_data = dst;
}

@end
