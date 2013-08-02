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

- (void)linearScaleQueue:(float)scale;
- (void)linearReduceQueue:(float)scale;
- (void)linearExpandQueue:(float)scale;

- (void)clipQueueHead:(NSRange)range;
- (void)clipQueueTail:(NSRange)range;
- (void)movingAverage:(NSUInteger)samples;
@end
