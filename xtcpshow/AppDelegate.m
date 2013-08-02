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
#import "DataResampler.h"

static void setup_interface(NSPopUpButton *);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Setup Model object
	[self setModel:[[CaptureModel alloc] init]];
	[[self model] setController:self]; // weak

	// widget initialization
	[[self graphView] initData];
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
		[self.model resetCounter];
		
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
	CaptureModel *model = [self model];
	GraphView *view = [self graphView];
	DataQueue *data = [model data];
	DataResampler *sampler = [view sampler];

	[sampler importData:data];
	[view setResolution:[model target_resolution]];
	[self updateUserInterface];
}

- (void)samplingError
{
	[[self startButton] setTitle:@"START"];
	[[self deviceSelector] setEnabled:YES];
	[[self filterField] setEnabled:YES];
	[self updateUserInterface];
}

- (void)updateUserInterface {
	[self.snapshotField
	 setFloatValue:[self.model mbps]];
	[self.maxField
	 setFloatValue:[self.model max_mbps]];
	[self.trendField
	 setFloatValue:[self.model peek_hold_mbps]];
	[self.totalpktField
	 setIntegerValue:[self.model total_pkts]];
	[self.samplingTargetField
	 setFloatValue:[self.model target_resolution]];
	[self.samplingField
	 setFloatValue:[self.model resolution]];
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