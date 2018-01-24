// Copyright (c) 2013
// SUENAGA Hiroki <hiroki_suenaga@mac.com>. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
//  FIR.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/12.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "FIR.h"
#import "ComputeQueue.h"

@implementation FIR
@synthesize tap;
@synthesize stage;

#define KZ_STAGE 3

- (id)init
{
    self = [super init];
    return self;
}

+ (id)FIRwithTap:(size_t)tap
{
    FIR *new = [[FIR alloc] init];
    NSUInteger tapStage = tap / KZ_STAGE;
    
    if (tapStage <= 0) {
        tapStage = 1;
    }
    new->tap = tapStage * KZ_STAGE;

    NSMutableArray *FIR_Factory = [[NSMutableArray alloc] init];
    for (int i = 0; i < KZ_STAGE; i++) {
        ComputeQueue *stage = [ComputeQueue queueWithZero:tapStage];
        [FIR_Factory addObject:stage];
    }
    new->stage = [NSArray arrayWithArray:FIR_Factory];
    
    return new;
}

- (DerivedData *)filter:(DerivedData *)sample
{
    for (int i = 0; i < [self.stage count]; i++) {
        NSDate *timestamp = [sample timestamp];
        NSUInteger samples = [sample numberOfSamples];
        [[self.stage objectAtIndex:i] enqueue:sample withTimestamp:timestamp];
        float value = [[self.stage objectAtIndex:i] averageDoubleValue];
        sample = [DerivedData dataWithDouble:value atDate:timestamp fromSamples:samples];
    }
    
    return sample;
}
@end
