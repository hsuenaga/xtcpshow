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
	
	[self setTrack:aTrack];
	[self updateUserInterface];
}

- (IBAction)mute:(id)sender {
	[self.track setVolume:0.0];
	[self updateUserInterface];
	
	NSLog(@"received a mute: message");
}

- (IBAction)takeFloatValueForVolumeFrom:(id)sender {
	float newValue;
	NSString *senderName = NULL;
	
	newValue = [sender floatValue];
	[self.track setVolume:newValue];
	[self updateUserInterface];
	
	if (sender == self.textField)
		senderName = @"textFiled";
	else if (sender == self.slider)
		senderName = @"slider";
	else
		senderName = @"unkonwon";
	NSLog(@"%@ sent takeFloatValueForVolumeFrom: with value %1.2f ",
	    senderName, newValue);
}

- (void)updateUserInterface {
	float newValue;
	
	newValue = [self.track volume];
	[self.textField setFloatValue:newValue];
	[self.slider setFloatValue:newValue];
}
@end
