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
}

- (IBAction)mute:(id)sender {
	NSLog(@"received a mute: message");
}

- (IBAction)takeFloatValueForVolumeFrom:(id)sender {
	NSString *senderName = NULL;
	
	if (sender == self.textField)
		senderName = @"textFiled";
	else if (sender == self.slider)
		senderName = @"slider";
	else
		senderName = @"unkonwon";
	NSLog(@"%@ sent takeFloatValueForVolumeFrom: with value %1.2f ",
	    senderName, [ sender floatValue ]);
}
@end
