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
//  GraphView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class AppDelegate;
@class GraphData;
@class Queue;
@class ComputeQueue;
@class DataResampler;
@class TrafficIndex;
@class TrafficDB;

extern NSString *const RANGE_AUTO;
extern NSString *const RANGE_PEAKHOLD;
extern NSString *const RANGE_MANUAL;

extern NSString *const FIR_NONE;
extern NSString *const FIR_SMA;
extern NSString *const FIR_TMA;
extern NSString *const FIR_GAUS;

extern NSString *const FILL_NONE;
extern NSString *const FILL_SIMPLE;
extern NSString *const FILL_RICH;

enum e_fill_mode {
    E_FILL_NONE,
    E_FILL_SIMPLE,
    E_FILL_RICH
};

@interface GraphView : NSView {
    NSTimeInterval _viewTimeLength;
    NSTimeInterval _FIRTimeLength;
}
@property (weak) AppDelegate *controller;

// statistics
@property (assign, readonly, atomic) NSUInteger maxSamples;
@property (assign, readonly, atomic) double maxValue;
@property (assign, readonly, atomic) double averageValue;

// configuration
@property (assign) NSTimeInterval minViewTimeLength;
@property (assign) NSTimeInterval viewTimeLength;
@property (assign) NSTimeInterval maxViewTimeLength;

@property (assign) NSTimeInterval minFIRTimeLength;
@property (assign) NSTimeInterval FIRTimeLength;
@property (assign) NSTimeInterval maxFIRTimeLength;

@property (assign) BOOL showPacketMarker;
@property (assign) BOOL showDeviationBand;
@property (assign) BOOL useHistgram;
@property (assign) BOOL useOutline;
@property (assign) enum e_fill_mode fillMode;

@property (assign) double animationFPS;

// Action from UI
- (float)setRange:(NSString *)mode withRange:(float)range;
- (float)setRange:(NSString *)mode withStep:(int)step;
- (int)stepValueFromRange:(float)range;
- (void)startPlot:(BOOL)repeat;
- (void)stopPlot;
- (void)setFIRMode:(NSString *)mode;
- (void)setBPSFillMode:(NSString *)mode;

// Action from window server
- (void)magnifyWithEvent:(NSEvent *)event;
- (void)scrollWheel:(NSEvent *)event;
- (void)drawRect:(NSRect)rect;
- (void)refreshData;
- (void)drawLayerToGC;

// Data-Binding
- (void)importData:(TrafficDB *)dataBase;
- (void)purgeData;
- (void)saveFile:(TrafficDB *)dataBase;
@end
