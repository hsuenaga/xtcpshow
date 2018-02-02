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
@class PID;
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

extern NSString *const CAP_MAX_SMPL;
extern NSString *const CAP_MAX_MBPS;
extern NSString *const CAP_AVG_MBPS;

extern NSString *const FMT_RANGE;
extern NSString *const FMT_DATE;
extern NSString *const FMT_NODATA;

enum e_fill_mode {
    E_FILL_NONE,
    E_FILL_SIMPLE,
    E_FILL_RICH
};

@interface GraphView : NSView {
    NSTimeInterval _viewTimeLength;
    NSTimeInterval _viewTimeOffset;
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

@property (assign) NSTimeInterval minViewTimeOffset;
@property (assign) NSTimeInterval viewTimeOffset;
@property (assign) NSTimeInterval maxViewTimeOffset;

@property (assign) NSTimeInterval minFIRTimeLength;
@property (assign) NSTimeInterval FIRTimeLength;
@property (assign) NSTimeInterval maxFIRTimeLength;

@property (assign) BOOL showPacketMarker;
@property (assign) BOOL showDeviationBand;
@property (assign) BOOL useHistgram;
@property (assign) BOOL useOutline;
@property (assign) enum e_fill_mode fillMode;

// Animation
@property (assign) double animationFPS;

// Graphic Components
@property (nonatomic) CGLayerRef CGBackbuffer;
@property (atomic)    NSGraphicsContext* NSBackbuffer;
@property (nonatomic) NSGraphicsContext *layerBackbufferContext;
@property (nonatomic) NSMutableDictionary *textAttributes;
@property (nonatomic) NSGradient *gradGraph;
@property (nonatomic) NSBezierPath *pathSolid;
@property (nonatomic) NSBezierPath *pathBold;
@property (nonatomic) NSBezierPath *pathDash;
@property (nonatomic) NSColor *colorBG;
@property (nonatomic) NSColor *colorFG;
@property (nonatomic) NSColor *colorAVG;
@property (nonatomic) NSColor *colorDEV;
@property (nonatomic) NSColor *colorBPS;
@property (nonatomic) NSColor *colorPPS;
@property (nonatomic) NSColor *colorMAX;
@property (nonatomic) NSColor *colorGRID;
@property (nonatomic) NSColor *colorGradStart;
@property (nonatomic) NSColor *colorGradEnd;
@property (nonatomic) NSDateFormatter *dateFormatter;
@property (atomic) NSTimer *timerAnimation;
@property (atomic) NSOperationQueue *cueAnimation;
@property (atomic) BOOL cueActive;
@property (atomic) BOOL bgReady;
@property (atomic) NSRect lastBounds;

// Range adjustment
@property (nonatomic) NSString *range_mode;
@property (nonatomic) double manual_range;
@property (nonatomic) double peak_range;
@property (nonatomic) NSUInteger GraphOffset;
@property (nonatomic) NSUInteger XmarkOffset;
@property (nonatomic) double y_range;
@property (nonatomic) NSUInteger pps_range;

// Data Binding
@property (weak, atomic) ComputeQueue *viewData;
@property (atomic) PID *PID;
@property (atomic) NSDate *lastResample;
@property (weak, atomic) TrafficDB *inputData;

// Action from UI
- (float)setRange:(NSString *)mode withRange:(float)range;
- (float)setRange:(NSString *)mode withStep:(int)step;
- (int)stepValueFromRange:(float)range;
- (void)setFIRMode:(NSString *)mode;
- (void)setBPSFillMode:(NSString *)mode;
- (void)setFPSRate:(NSString *)rate;

// UI helper
- (void)createFIRButton:(NSPopUpButton *)btn;
- (void)createRangeButton:(NSPopUpButton *)btn;
- (void)createFillButton:(NSPopUpButton *)btn;
- (void)createFPSButton:(NSPopUpButton *)btn;

// Action from window server
- (void)magnifyWithEvent:(NSEvent *)event;
- (void)scrollWheel:(NSEvent *)event;

- (void)updateRange;

// Data Processing
- (BOOL)resampleDataInRect:(NSRect)rect;
- (void)importData:(TrafficDB *)dataBase;
- (void)purgeData;
- (void)saveFile:(TrafficDB *)dataBase;

- (double)saturateDouble:(double)value withMax:(double)max withMin:(double)min roundBy:(double)round;

//
- (void)copyConfiguration:(GraphView *)graph;
@end
