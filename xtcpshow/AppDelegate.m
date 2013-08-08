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
static NSString *const LBL_CAP_ERROR=@"Capture ERROR";

static NSString *const DEF_DEVICE=@"en0";
static NSString *const PREFER_DEVICE=@"en";

static void setup_interface(NSPopUpButton *);

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Setup Model object
	[self setModel:[[CaptureModel alloc] init]];
	[[self model] setController:self]; // weak

	// widget initialization
	[[self graphView] initData];
	[[self graphView] setRange:RANGE_AUTO withRange:0.0];
	[[self startButton] setEnabled:TRUE];

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
		[self.model stopCapture];
		[[self startButton] setTitle:LBL_START];
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

		[[self startButton] setTitle:LBL_STOP];
		input_enabled = FALSE;

		_timer =
		[NSTimer timerWithTimeInterval:UPDATE_INT
					target:self
				      selector:@selector(animationNotify:)
				      userInfo:nil
				       repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_timer
					     forMode:NSRunLoopCommonModes];

		if ([self.model startCapture] < 0) {
			[[self startButton] setTitle:LBL_START];
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
	if (isnan(range) || isinf(range))
		range = 0.0;
	if (mode != RANGE_MANUAL)
		return;

	step = [_rangeStepper intValue];
	range = [_graphView setRange:mode withStep:step];
	[_rangeField setFloatValue:range];
}

- (IBAction)enterRange:(id)sender {
	NSString *mode;
	float range = 0.0;

	mode = [_rangeSelector titleOfSelectedItem];
	if (mode != RANGE_MANUAL)
		return;

	range = [_rangeField floatValue];
	if (isnan(range) || isinf(range))
		range = 0.0;

	range = [_graphView setRange:mode withRange:range];
	[_rangeField setFloatValue:range];
}

- (IBAction)setRangeType:(id)sender {
	NSString *mode;
	float range = 0.0;

	mode = [_rangeSelector titleOfSelectedItem];
	if (mode == RANGE_MANUAL) {
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

	[self.graphView setNeedsDisplay:YES];
	[self updateUserInterface];
}

- (void)samplingError:(NSString *)message
{
	NSAlert *alert;

	[[self startButton] setTitle:LBL_START];
	[[self deviceSelector] setEnabled:YES];
	[[self filterField] setEnabled:YES];

	alert = [NSAlert alertWithMessageText:LBL_CAP_ERROR
				defaultButton:LBL_OK
			      alternateButton:nil
				  otherButton:nil
		    informativeTextWithFormat:@"%@", message];
	[alert runModal];

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
