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
	[[self graphView] setRange:@"Auto" withRange:0.0];
	[[self startButton] setEnabled:TRUE];

	// setup intrface labels
	setup_interface([self deviceSelector]);

	// setup range labels
	[_rangeSelector removeAllItems];
	[_rangeSelector addItemWithTitle:@"Auto"];
	[_rangeSelector addItemWithTitle:@"PeakHold"];
	[_rangeSelector addItemWithTitle:@"Manual"];
	[_rangeSelector selectItemWithTitle:@"Auto"];

	[self updateUserInterface];
}

- (IBAction)startCapture:(id)sender {
	BOOL input_enabled;

	if ([self.model captureEnabled]) {
		/* stop capture */
		[self.model stopCapture];
		[[self startButton] setTitle:@"START"];
		input_enabled = TRUE;
		if (_timer)
			[_timer invalidate];
	}
	else {
		/* start capture */
		[self.model resetCounter];

		self.model.device =
		[[self.deviceSelector titleOfSelectedItem] cStringUsingEncoding:NSASCIIStringEncoding];
		self.model.filter =
		[[[self filterField] stringValue] cStringUsingEncoding:NSASCIIStringEncoding];
		[[self graphView] setTargetTimeLength:[[self zoomBar] intValue]];
		[[self graphView] setSMASize:[[self smoothBar] intValue]];

		[[self startButton] setTitle:@"STOP"];
		input_enabled = FALSE;

		_timer =
		[NSTimer timerWithTimeInterval:(1.0f/12.0f)
					target:self
				      selector:@selector(animationNotify:)
				      userInfo:nil
				       repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_timer
					     forMode:NSRunLoopCommonModes];

		if ([self.model startCapture] < 0) {
			/* XXX: report error */
			[[self startButton] setTitle:@"START"];
			input_enabled = TRUE;
			[_timer invalidate];
		}
	}

	[[self deviceSelector] setEnabled:input_enabled];
	[[self filterField] setEnabled:input_enabled];
	[self updateUserInterface];
}

- (IBAction)changeZoom:(id)sender {
	[[self graphView] setTargetTimeLength:[sender intValue]];
	[self animationNotify:nil];
	[self updateUserInterface];
}

- (IBAction)changeSmooth:(id)sender {
	[[self graphView] setSMASize:[sender intValue]];
	[self animationNotify:nil];
	[self updateUserInterface];
}

- (IBAction)changeRange:(id)sender {
	NSString *mode;
	float range = 0.0;
	int step;

	mode = [_rangeSelector titleOfSelectedItem];
	range = [_rangeField floatValue];
	if (range == NAN)
		range = 0.0;
	if (![mode isEqualToString:@"Manual"])
		return;

	step = [_rangeStepper intValue];
	if (step == 0) {
		range = 0.5;
	}
	else if (step == 1) {
		range = 1.0;
	}
	else if (step == 2) {
		range = 2.5;
	}
	else {
		range = 5.0 * (float)(step - 1);
	}
	[_rangeField setFloatValue:range];
	[_graphView setRange:mode withRange:range];
}

- (IBAction)enterRange:(id)sender {
	NSString *mode;
	float range = 0.0;

	mode = [_rangeSelector titleOfSelectedItem];
	if (![mode isEqualToString:@"Manual"])
		return;
	range = [_rangeField floatValue];
	if (range == NAN)
		range = 0.0;

	range = [_graphView setRange:mode withRange:range];
	[_rangeField setFloatValue:range];
}

- (IBAction)setRangeType:(id)sender {
	NSString *mode;
	float range = 0.0;

	mode = [_rangeSelector titleOfSelectedItem];
	if ([mode isEqualToString:@"Manual"]) {
		[_rangeField setEnabled:YES];
		[_rangeStepper setEnabled:YES];
		[self enterRange:self];
	}
	else {
		[_rangeStepper setEnabled:NO];
		[_rangeField setEnabled:NO];
	}

	[_graphView setRange:mode withRange:range];
}

- (void)animationNotify:(id)sender
{
	CaptureModel *model = [self model];
	GraphView *view = [self graphView];

	[view importData:[model data]];

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
	 setFloatValue:([self.model getSamplingInterval] * 1000.0f)];
	[self.samplingField
	 setFloatValue:([self.model snapSamplingInterval] * 1000.0f)];
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