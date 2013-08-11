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

- (void)scaleAllValue:(float)scale;

- (void)alignWithTick:(NSTimeInterval)tick fromDate:(NSDate *)start toDate:(NSDate *)end;

- (void)clipQueueFromDate:(NSDate *)start;

- (void)triangleMovingAverage:(NSUInteger)samples;

- (void)invalidValueException;
@end
