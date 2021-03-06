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
//  AppDelegate.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CaptureModel;
@class GraphView;
@class CaptureBPF;

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* Main window */
@property (assign) IBOutlet NSWindow *window;

/* Configuration TAB(CH1) */
@property (weak) IBOutlet NSPopUpButton *deviceSelector;
@property (weak) IBOutlet NSTextField *filterField;
@property (weak) IBOutlet NSTextField *rangeField;
@property (weak) IBOutlet NSStepper *rangeStepper;
@property (weak) IBOutlet NSPopUpButton *rangeSelector;
@property (weak) IBOutlet NSButton *promiscCheck;

/* Configuration TAB(CH2) */
@property (weak) IBOutlet NSPopUpButton *deviceSelectorCH2;
@property (weak) IBOutlet NSTextField *filterFieldCH2;
@property (weak) IBOutlet NSTextField *rangeFieldCH2;
@property (weak) IBOutlet NSStepper *rangeStepperCH2;
@property (weak) IBOutlet NSPopUpButton *rangeSelectorCH2;
@property (weak) IBOutlet NSButton *promiscCheckCH2;

/* Graphics TAB */
@property (weak) IBOutlet NSPopUpButton *kzDepth;
@property (weak) IBOutlet NSButton *bpsOutlineEnable;
@property (weak) IBOutlet NSPopUpButton *bpsFillMode;
@property (weak) IBOutlet NSPopUpButton *fpsRate;

/* Status TAB */
@property (weak) IBOutlet NSTextField *snapshotField;
@property (weak) IBOutlet NSTextField *maxField;
@property (weak) IBOutlet NSTextField *averageField;
@property (weak) IBOutlet NSTextField *totalpktField;
@property (weak) IBOutlet NSTextField *samplingField;
@property (weak) IBOutlet NSTextField *samplingTargetField;

/* Graph BOX */
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSSlider *zoomBar;
@property (weak) IBOutlet NSSlider *smoothBar;

// Graph Tab
@property (weak) IBOutlet NSTabView *GraphTab;
@property (weak) IBOutlet NSView *GraphTabSingleView;
@property (weak) IBOutlet GraphView *graphView;
@property (weak) IBOutlet NSView *GraphTabSplitView;
@property (weak) IBOutlet GraphView *graphViewSplit1;
@property (weak) IBOutlet GraphView *graphViewSplit2;

/* Action from view */
- (IBAction)startCapture:(id)sender;
- (IBAction)changeZoom:(id)sender;
- (IBAction)changeSmooth:(id)sender;
- (IBAction)changeRange:(id)sender;
- (IBAction)enterRange:(id)sender;
- (IBAction)setRangeType:(id)sender;
- (IBAction)togglePacketMarker:(id)sender;
- (IBAction)toggleDeviation:(id)sender;
- (IBAction)copyGraphView:(id)sender;

/* Action form CustomView (GraphView) */
- (void)zoomGesture:(id)sender;
- (void)scrollGesture:(id)sender;

/* the model */
@property (strong) CaptureModel *model;
@property (strong) NSTimer *timer;

/* notify from model, controller(myself), ... */
- (void) closeNotify:(NSNotification *)notify;
- (void) samplingError:(NSString *)message;
- (void) updateUserInterface;
@end
