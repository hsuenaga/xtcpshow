//
//  AppDelegate.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CaptureModel;
@class GraphView;

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* Main window */
@property (assign) IBOutlet NSWindow *window;

/* Configuration TAB */
@property (weak) IBOutlet NSPopUpButton *deviceSelector;
@property (weak) IBOutlet NSTextField *filterField;

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

/* the model */
@property (strong) CaptureModel *model;

/* notify from model, controller(myself), ... */
- (void) samplingNotify;
- (void) samplingError;
- (void) updateUserInterface;
@end
