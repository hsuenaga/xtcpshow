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
//  CaptureModel.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#import <Foundation/Foundation.h>

#import "CaptureBPF.h"
#import "TrafficDB.h"
#import "AppDelegate.h"

#define DEF_HISTORY 50000 // packets

@class TrafficIndex;

@interface CaptureModel : NSObject
// pcap binding
@property (assign, nonatomic) const char *device;
@property (assign, nonatomic) const char *filter;
@property (assign, nonatomic) BOOL promisc;
@property (strong, nonatomic) CaptureBPF *bpfc;

// data base
@property (strong, nonatomic, readonly) TrafficDB *dataBase;

// traffic data reported by capture thread
@property (assign, atomic) uint64_t totalPkts;
@property (assign, atomic) double mbps;
@property (assign, atomic) double max_mbps;
@property (assign, atomic) double average_mbps;
@property (assign, atomic) double samplingInterval; // [sec]
@property (assign, atomic) double samplingIntervalLast; // [sec]

// data processing (don't acccess from other thread)
@property (weak, nonatomic) AppDelegate *controller;

- (CaptureModel *)init;
- (BOOL)startCapture;
- (void)stopCapture;
- (BOOL)captureEnabled;
- (void)resetCounter;

- (double)samplingIntervalMS;
- (double)samplingIntervalLastMS;

- (void)recvError:(NSString *)message;
- (void)recvFinish:(id)sender;
@end
