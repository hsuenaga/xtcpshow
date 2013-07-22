//
//  AppDelegate.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *textField;
@property (strong) Track *track;

- (IBAction)startCapture:(id)sender;
- (void) updateUserInterface;

@end
