//
//  AppDelegate.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if.h>
#include <ifaddrs.h>

#import "AppDelegate.h"
#import "CaptureModel.h"
#import "GraphView.h"

static void setup_interface(NSPopUpButton *);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Setup Model object
	[self setModel:[[CaptureModel alloc] init]];
	[[self model] setController:self]; // weak

	// widget initialization
	[[self graphView] allocHist];
	[[self startButton] setEnabled:TRUE];
	
	// setup intrface labels
	setup_interface([self deviceSelector]);

	[self updateUserInterface];
}

- (IBAction)startCapture:(id)sender {
	BOOL input_enabled;
	
	if ([self.model captureEnabled]) {
		/* stop capture */
		[self.model stopCapture];
		[[self startButton] setTitle:@"START"];
		input_enabled = TRUE;
	}
	else {
		/* start capture */
		self.model.device =
		[[self.deviceSelector titleOfSelectedItem] cStringUsingEncoding:NSASCIIStringEncoding];
		self.model.filter =
		[[[self filterField] stringValue] cStringUsingEncoding:NSASCIIStringEncoding];
		[[self graphView] setWindowSize:[[self zoomBar] intValue]];
		[[self graphView] setSMASize:[[self smoothBar] intValue]];
				
		[[self startButton] setTitle:@"STOP"];
		input_enabled = FALSE;

		if ([self.model startCapture] < 0) {
			/* XXX: report error */
			[[self startButton] setTitle:@"START"];
			input_enabled = TRUE;
		}
	}

	[[self deviceSelector] setEnabled:input_enabled];
	[[self filterField] setEnabled:input_enabled];
	[self updateUserInterface];
}

- (IBAction)changeZoom:(id)sender {
	[[self graphView] setWindowSize:[sender intValue]];
	[self updateUserInterface];
}

- (IBAction)changeSmooth:(id)sender {
	[[self graphView] setSMASize:[sender intValue]];
	[self updateUserInterface];
}

- (void)samplingNotify
{
	[[self graphView] addSnap:[self.model mbps]
			trendData:[self.model aged_mbps]
		       resolusion:[self.model target_resolution]];

	[self updateUserInterface];
}

- (void)updateUserInterface {
	[self.snapshotField setFloatValue:[self.model mbps]];
	[self.maxField setFloatValue:[self.model max_mbps]];
	[self.trendField setFloatValue:[self.model aged_mbps]];
	[self.totalpktField setIntegerValue:[self.model total_pkts]];
	[self.graphView setNeedsDisplay:YES];
}
@end

/*
 * C API bridge
 */
static void setup_interface(NSPopUpButton *btn)
{
	struct ifaddrs *ifap0, *ifap;
	
	if (getifaddrs(&ifap0) < 0)
		return;
	
	[btn removeAllItems];
	
	for (ifap = ifap0; ifap; ifap = ifap->ifa_next) {
		NSString *if_name, *exist_name;
		NSArray *name_array;
		NSEnumerator *enumerator;
		
		if (ifap->ifa_flags & IFF_LOOPBACK)
			continue;
		if (!(ifap->ifa_flags & IFF_UP))
			continue;
		if (!(ifap->ifa_flags & IFF_RUNNING))
			continue;
		
		if_name = [NSString
			   stringWithCString:ifap->ifa_name
			   encoding:NSASCIIStringEncoding];
		name_array = [btn itemTitles];
		enumerator = [name_array objectEnumerator];
		while (exist_name = [enumerator nextObject]) {
			if ([if_name isEqualToString:exist_name]) {
				if_name = nil;
				break;
			}
		}
		if (if_name == nil)
			continue;
		
		[btn addItemWithTitle:if_name];
		if ([if_name isEqualToString:@"en0"])
			[btn selectItemWithTitle:if_name];
		else {
			NSRange range;
			range = [if_name rangeOfString:@"en"];
			if (range.location != NSNotFound)
				[btn selectItemWithTitle:if_name];
		}
	}
	
	freeifaddrs(ifap0);
}