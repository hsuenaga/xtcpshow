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

	// MA filter states
	DataQueue *sma[2];
}

@property (strong, readonly) DataQueue *data;
@property (weak, readonly) DataQueue *lastInput;
@property (assign) NSUInteger outputSamples;
@property (assign) NSTimeInterval outputTimeLength;
@property (assign) NSTimeInterval outputTimeOffset;
@property (assign) NSTimeInterval MATimeLength;
@property (assign, readonly) NSUInteger overSample;

// protected
- (DataQueue *)copyQueue:(DataQueue *)source FromDate:(NSDate *)start;
- (void)invalidValueException;

// public
- (void)purgeData;
- (void)resampleData:(DataQueue *)input;

@end
