//
//  AppDelegate.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "AppDelegate.h"
#import "Capture.h"
#import "CaptureView.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	TCPShowModel *model;
	
	model = [[TCPShowModel alloc] init];
	[model setController:self];
	[[self graphView] allocHist];
	[[self graphView] setModel:model];
	[self setModel:model];

	[[self startButton] setEnabled:TRUE];
	[[self stopButton] setEnabled:FALSE];
	[self updateUserInterface];
}

- (IBAction)startCapture:(id)sender {
	self.model.device =
	    [[[self deviceField] stringValue] cStringUsingEncoding:NSASCIIStringEncoding];
	self.model.filter =
	    [[[self filterField] stringValue] cStringUsingEncoding:NSASCIIStringEncoding];
	[[self startButton] setEnabled:FALSE];
	[[self stopButton] setEnabled:TRUE];
	if ([self.model startCapture] < 0) {
		[[self startButton] setEnabled:TRUE];
		[[self stopButton] setEnabled:FALSE];
		return;
	}
	[self updateUserInterface];
}

- (IBAction)stopCapture:(id)sender {
	[[self stopButton] setEnabled:FALSE];
	[[self startButton] setEnabled:TRUE];
	[self.model stopCapture];
	[self updateUserInterface];
}

- (void)updateUserInterface {
	float newValue, newMax, newAge;
	
	newValue = [self.model mbps];
	newMax = [self.model max_mbps];
	newAge = [self.model aged_mbps];
	
	[self.textField setFloatValue:newValue];
	[self.maxField setFloatValue:newMax];
	[self.ageField setFloatValue:newAge];
	[self.graphView setNeedsDisplay:YES];
//	NSLog(@"got mbps from model: %f [mbps]", newValue);
}

@end
