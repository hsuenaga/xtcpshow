//
//  AppDelegate.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "AppDelegate.h"
#import "Track.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	Track *aTrack = [[Track alloc] init];

	[aTrack setController:self];
	[self setTrack:aTrack];
	[self updateUserInterface];
}

- (IBAction)startCapture:(id)sender {
	[self.track startCapture];
	[self updateUserInterface];
}

- (void)updateUserInterface {
	float newValue;
	
	newValue = [self.track mbps];
	[self.textField setFloatValue:newValue];
	NSLog(@"mbps = %f", newValue);
}

@end
