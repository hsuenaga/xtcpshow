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
	DataQueue *original;
}

@property (strong, readonly) DataQueue *data;

- (void)importData:(DataQueue *)data;
- (void)purgeData;

- (void)scaleQueue:(float)scale;
- (void)clipQueueHead:(NSRange)range;
- (void)clipQueueTail:(NSRange)range;
- (void)movingAverage:(NSUInteger)samples;
@end
