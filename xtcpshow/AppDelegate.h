//
//  AppDelegate.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TCPShowModel;
@class CaptureView;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *textField;
@property (weak) IBOutlet NSTextField *maxField;
@property (weak) IBOutlet NSTextField *ageField;
@property (weak) IBOutlet NSButton *startButton;
@property (weak) IBOutlet NSButton *stopButton;
@property (weak) IBOutlet CaptureView *graphView;
@property (weak) IBOutlet NSTextField *deviceField;
@property (weak) IBOutlet NSTextField *filterField;

@property (strong) TCPShowModel *model;

- (IBAction)startCapture:(id)sender;
- (IBAction)stopCapture:(id)sender;
- (void) updateUserInterface;

@end
