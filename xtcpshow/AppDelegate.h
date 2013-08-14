//
//  AppDelegate.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#define UPDATE_FPS (10.0f)
#define UPDATE_INT (1.0f/UPDATE_FPS)

@class CaptureModel;
@class GraphView;

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* Main window */
@property (assign) IBOutlet NSWindow *window;

/* Configuration TAB */
@property (weak) IBOutlet NSPopUpButton *deviceSelector;
@property (weak) IBOutlet NSTextField *filterField;
@property (weak) IBOutlet NSTextField *rangeField;
@property (weak) IBOutlet NSStepper *rangeStepper;
@property (weak) IBOutlet NSPopUpButton *rangeSelector;
@property (weak) IBOutlet NSButton *promiscCheck;

/* Status TAB */
@property (weak) IBOutlet NSTextField *snapshotField;
@property (weak) IBOutlet NSTextField *maxField;
@property (weak) IBOutlet NSTextField *trendField;
@property (weak) IBOutlet NSTextField *totalpktField;
@property (weak) IBOutlet NSTextField *samplingField;
@property (weak) IBOutlet NSTextField *samplingTargetField;

/* Graph BOX */
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSSlider *zoomBar;
@property (weak) IBOutlet NSSlider *smoothBar;
@property (weak) IBOutlet GraphView *graphView;

/* Action from view */
- (IBAction)startCapture:(id)sender;
- (IBAction)changeZoom:(id)sender;
- (IBAction)changeSmooth:(id)sender;
- (IBAction)changeRange:(id)sender;
- (IBAction)enterRange:(id)sender;
- (IBAction)setRangeType:(id)sender;
- (IBAction)togglePacketMarker:(id)sender;

/* Action form CustomView (GraphView) */
- (void)zoomGesture:(id)sender;
- (void)scrollGesture:(id)sender;

/* the model */
@property (strong) CaptureModel *model;
@property (strong) NSTimer *timer;

/* notify from model, controller(myself), ... */
- (void) animationNotify:(NSTimer *)sender;
- (void) samplingError:(NSString *)message;
- (void) updateUserInterface;

/* initialize environment */
- (void) setupInterfaceButton:(NSPopUpButton *)btn;
@end
