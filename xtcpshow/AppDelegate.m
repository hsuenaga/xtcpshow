//
//  AppDelegate.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "AppDelegate.h"
#import "Capture.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	TCPShowModel *model;
	
	model = [[TCPShowModel alloc] init];
	[model setController:self];
	[self setModel:model];
	[[self startButton] setEnabled:TRUE];
	[[self stopButton] setEnabled:FALSE];
	[self updateUserInterface];
}

- (IBAction)startCapture:(id)sender {
	[[self startButton] setEnabled:FALSE];
	[[self stopButton] setEnabled:TRUE];
	[self.model startCapture];
	[self updateUserInterface];
}

- (IBAction)stopCapture:(id)sender {
	[[self stopButton] setEnabled:FALSE];
	[[self startButton] setEnabled:TRUE];
	[self.model stopCapture];
	[self updateUserInterface];
}

- (void)updateUserInterface {
	float newValue;
	
	newValue = [self.model mbps];
	[self.textField setFloatValue:newValue];
//	NSLog(@"got mbps from model: %f [mbps]", newValue);
}

@end
