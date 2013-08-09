//
//  DataResampler.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/02.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DataQueue.h"

@interface DataResampler : NSObject {
	BOOL write_protect;
}

@property (strong, readonly) DataQueue *data;

- (void)importData:(DataQueue *)data;
- (void)makeMutable;
- (void)purgeData;

- (void)scaleAllValue:(float)scale;

- (void)discreteScaleQueue:(float)scale;

- (void)alignWithTick:(NSTimeInterval)tick fromDate:(NSDate *)start toDate:(NSDate *)end;

- (void)linearScaleQueue:(float)scale;
- (void)linearDownSamplingQueue:(float)scale;
- (void)linearUpSamplingQueue:(float)scale;

- (void)clipQueueHead:(NSRange)range;
- (void)clipQueueTail:(NSRange)range;
- (void)clipQueueFromDate:(NSDate *)start;

- (void)movingAverage:(NSUInteger)samples;
- (void)triangleMovingAverage:(NSUInteger)samples;

- (void)invalidValueException;
@end
