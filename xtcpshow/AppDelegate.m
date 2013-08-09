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

static NSString *const LBL_START=@"START";
static NSString *const LBL_STOP=@"STOP";
static NSString *const LBL_OK=@"OK";
static NSString *const LBL_CAP_ERROR=@"CAPTURE ERROR";

static NSString *const DEF_DEVICE=@"en0";
static NSString *const PREFER_DEVICE=@"en";

static void setup_interface(NSPopUpButton *);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Setup Model object
	[self setModel:[[CaptureModel alloc] init]];
	[_model setController:self]; // weak

	// widget initialization
	[_graphView initData];
	[_graphView setRange:RANGE_AUTO withRange:0.0];
	[_graphView setShowPacketMarker:NO];
	[_startButton setEnabled:TRUE];

	// setup intrface labels
	[self setupInterfaceButton:_deviceSelector];

	// setup range labels
	[_rangeSelector removeAllItems];
	[_rangeSelector addItemWithTitle:RANGE_AUTO];
	[_rangeSelector addItemWithTitle:RANGE_PEEKHOLD];
	[_rangeSelector addItemWithTitle:RANGE_MANUAL];
	[_rangeSelector selectItemWithTitle:RANGE_AUTO];

	[self updateUserInterface];
}

- (IBAction)startCapture:(id)sender {
	BOOL input_enabled;

	if ([self.model captureEnabled]) {
		/* stop capture */
		[_model stopCapture];
		[_startButton setTitle:LBL_START];
		input_enabled = TRUE;
		if (_timer)
			[_timer invalidate];
	}
	else {
		/* start capture */
		[_model resetCounter];

		_model.device =	[[_deviceSelector titleOfSelectedItem] cStringUsingEncoding:NSASCIIStringEncoding];
		_model.filter =
		[[_filterField stringValue] cStringUsingEncoding:NSASCIIStringEncoding];
		[_graphView setTargetTimeLength:[_zoomBar intValue]];
		[_graphView setSMALength:[_smoothBar intValue]];

		[_startButton setTitle:LBL_STOP];
		input_enabled = FALSE;

		_timer =
		[NSTimer timerWithTimeInterval:UPDATE_INT
					target:self
				      selector:@selector(animationNotify:)
				      userInfo:nil
				       repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_timer
					     forMode:NSRunLoopCommonModes];

		[_model startCapture];
	}

	[_deviceSelector setEnabled:input_enabled];
	[_filterField setEnabled:input_enabled];
	[self updateUserInterface];
}

- (IBAction)changeZoom:(id)sender {
	[_graphView setTargetTimeLength:[sender intValue]];
	[self animationNotify:nil];
	[self updateUserInterface];
}

- (IBAction)changeSmooth:(id)sender {
	[_graphView setSMALength:[sender intValue]];
	[self animationNotify:nil];
	[self updateUserInterface];
}

- (IBAction)changeRange:(id)sender {
	NSString *mode;
	float range;
	int step;

	mode = [_rangeSelector titleOfSelectedItem];
	if (mode != RANGE_MANUAL)
		return;

	step = [_rangeStepper intValue];
	range = [_graphView setRange:mode withStep:step];
	NSLog(@"new range:%f", range);
	[_rangeField setFloatValue:range];
	[self updateUserInterface];
}

- (IBAction)enterRange:(id)sender {
	NSString *mode;
	float range;

	mode = [_rangeSelector titleOfSelectedItem];
	if (mode != RANGE_MANUAL)
		return;

	range = [_rangeField floatValue];
	if (isnan(range) || isinf(range))
		range = 0.0f;

	range = [_graphView setRange:mode withRange:range];
	[_rangeField setFloatValue:range];
	[_rangeStepper
	 setIntValue:[_graphView stepValueWithRange:range]];
	[self updateUserInterface];
}

- (IBAction)setRangeType:(id)sender {
	NSString *mode;

	mode = [_rangeSelector titleOfSelectedItem];
	if (mode == RANGE_MANUAL) {
		float range;

		[_rangeField setEnabled:YES];
		[_rangeStepper setEnabled:YES];
		range = [_rangeField floatValue];
		range = [_graphView setRange:mode withRange:range];
		[_rangeField setFloatValue:range];
		return;
	}

	[_rangeStepper setEnabled:NO];
	[_rangeField setEnabled:NO];
	[_graphView setRange:mode withRange:0.0f];
	[self updateUserInterface];
}

- (IBAction)togglePacketMarker:(id)sender {
	if ([sender state] == NSOnState)
		[_graphView setShowPacketMarker:YES];
	else
		[_graphView setShowPacketMarker:NO];
}

- (void)animationNotify:(id)sender
{
	[_graphView importData:[_model data]];
	[_graphView setNeedsDisplay:YES];

	[self updateUserInterface];
}

- (void)samplingError:(NSString *)message
{
	NSAlert *alert;

	[_startButton setTitle:LBL_START];
	[_deviceSelector setEnabled:YES];
	[_filterField setEnabled:YES];

	alert = [NSAlert alertWithMessageText:LBL_CAP_ERROR
				defaultButton:LBL_OK
			      alternateButton:nil
				  otherButton:nil
		    informativeTextWithFormat:@"%@", message];
	[alert runModal];

	[self updateUserInterface];
}

- (void)updateUserInterface {
	[_snapshotField	 setFloatValue:_model.mbps];
	[_maxField setFloatValue:_model.max_mbps];
	[_trendField setFloatValue:_model.peek_hold_mbps];
	[_totalpktField setIntegerValue:_model.total_pkts];

	[_samplingTargetField
	 setFloatValue:_model.samplingIntervalMS];
	[_samplingField
	 setFloatValue:_model.samplingIntervalLastMS];
}

- (void)setupInterfaceButton:(NSPopUpButton *)btn
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
		if ([if_name isEqualToString:DEF_DEVICE])
			[btn selectItemWithTitle:if_name];
		else {
			NSRange range;
			range = [if_name rangeOfString:PREFER_DEVICE];
			if (range.location != NSNotFound)
				[btn selectItemWithTitle:if_name];
		}
	}

	freeifaddrs(ifap0);
}
@end
