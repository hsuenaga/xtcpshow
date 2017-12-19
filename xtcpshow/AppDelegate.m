// Copyright (c) 2013
// SUENAGA Hiroki <hiroki_suenaga@mac.com>. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
//  AppDelegate.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if.h>
#include <ifaddrs.h>

#import <ServiceManagement/ServiceManagement.h>
#import <Security/Security.h>

#import "AppDelegate.h"
#import "CaptureModel.h"
#import "GraphView.h"
#import "DataResampler.h"
#import "BPFControl.h"

static NSString *const LBL_START=@"START";
static NSString *const LBL_STOP=@"STOP";
static NSString *const LBL_OK=@"OK";
static NSString *const LBL_CAP_ERROR=@"CAPTURE ERROR";

static NSString *const DEF_DEVICE=@"en0";
static NSString *const PREFER_DEVICE=@"en";

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Setup Model object
	[self setModel:[[CaptureModel alloc] init]];
	[_model setController:self]; // weak

	// widget initialization
	[_graphView setController:self];
	[_graphView setRange:RANGE_AUTO withRange:0.0];
	[_graphView setShowPacketMarker:NO];
	[_graphView setMaxViewTimeLength:[_zoomBar maxValue]];
	[_graphView setMinViewTimeLength:[_zoomBar minValue]];
	[_graphView setViewTimeLength:[_zoomBar floatValue]];
	[_graphView setMaxMATimeLength:[_smoothBar maxValue]];
	[_graphView setMinMATimeLength:[_smoothBar minValue]];
	[_graphView setMATimeLength:[_smoothBar floatValue]];
	[_graphView setNeedsDisplay:YES];
	[_startButton setEnabled:TRUE];

	// setup intrface labels
	[self setupInterfaceButton:_deviceSelector];

	// setup range labels
	[_rangeSelector removeAllItems];
	[_rangeSelector addItemWithTitle:RANGE_AUTO];
	[_rangeSelector addItemWithTitle:RANGE_PEAKHOLD];
	[_rangeSelector addItemWithTitle:RANGE_MANUAL];
	[_rangeSelector selectItemWithTitle:RANGE_AUTO];

	// notification center
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeNofity:) name:NSWindowWillCloseNotification object:nil];

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
		if ([_promiscCheck state] == NSOnState)
			_model.promisc = YES;
		else
			_model.promisc = NO;
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
	[_promiscCheck setEnabled:input_enabled];
	[self updateUserInterface];
}

- (IBAction)changeZoom:(id)sender {
	[_graphView setViewTimeLength:[sender floatValue]];
	[self animationNotify:nil];
	[self updateUserInterface];
}

- (IBAction)changeSmooth:(id)sender {
	[_graphView setMATimeLength:[sender floatValue]];
	[self animationNotify:nil];
	[self updateUserInterface];
}

- (void)zoomGesture:(id)sender
{
	float value;

	value = [_graphView viewTimeLength];
	[_zoomBar setFloatValue:value];
	[self animationNotify:nil];
	[self updateUserInterface];
}

- (void)scrollGesture:(id)sender
{
	float value;

	value = [_graphView MATimeLength];
	[_smoothBar setFloatValue:value];
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
	 setIntValue:[_graphView stepValueFromRange:range]];
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

	[_graphView purgeData];
	[_graphView importData:[_model data]];
	[_graphView setNeedsDisplay:YES];
}

- (IBAction)toggleDeviation:(id)sender {
	if ([sender state] == NSOnState)
		[_graphView setShowDeviationBand:YES];
	else
		[_graphView setShowDeviationBand:NO];

	[_graphView setNeedsDisplay:YES];
}

- (IBAction)copyGraphView:(id)sender {
	[_graphView saveFile:[_model data]];
}

- (void)closeNofity:(id)sender
{
	NSLog(@"close window. exitting..");
	[_model stopCapture];
	[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (void)animationNotify:(id)sender
{
	[_model animationTick];
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

    alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setMessageText:LBL_CAP_ERROR];
    if (message)
        [alert setInformativeText:message];
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
