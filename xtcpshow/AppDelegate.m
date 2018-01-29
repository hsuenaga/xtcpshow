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
#import "CaptureBPF.h"
#import "OpenBPFService.h"

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
	[self.model setController:self]; // weak

	// widget initialization
	[self.graphView setController:self];
	[self.graphView setRange:RANGE_AUTO withRange:0.0];
	[self.graphView setShowPacketMarker:NO];
    [self.graphView setUseHistgram:NO];
	[self.graphView setMaxViewTimeLength:[self.zoomBar maxValue]];
	[self.graphView setMinViewTimeLength:[self.zoomBar minValue]];
	[self.graphView setViewTimeLength:[self.zoomBar floatValue]];
	[self.graphView setMaxFIRTimeLength:[self.smoothBar maxValue]];
	[self.graphView setMinFIRTimeLength:[self.smoothBar minValue]];
	[self.graphView setFIRTimeLength:[self.smoothBar floatValue]];
	[self.graphView setNeedsDisplay:YES];
	[self.startButton setEnabled:TRUE];

	// setup intrface labels
	[self setupInterfaceButton:self.deviceSelector];

	// setup range labels
	[self.rangeSelector removeAllItems];
	[self.rangeSelector addItemWithTitle:RANGE_AUTO];
	[self.rangeSelector addItemWithTitle:RANGE_PEAKHOLD];
	[self.rangeSelector addItemWithTitle:RANGE_MANUAL];
	[self.rangeSelector selectItemWithTitle:RANGE_AUTO];
    
    // setup fillMode labels
    [self.bpsFillMode removeAllItems];
    [self.bpsFillMode addItemWithTitle:FILL_NONE];
    [self.bpsFillMode addItemWithTitle:FILL_SIMPLE];
    [self.bpsFillMode addItemWithTitle:FILL_RICH];
    [self.bpsFillMode selectItemWithTitle:FILL_RICH];
    
    // setup FIR labels
    [self.kzDepth removeAllItems];
    [self.kzDepth addItemWithTitle:FIR_NONE];
    [self.kzDepth addItemWithTitle:FIR_SMA];
    [self.kzDepth addItemWithTitle:FIR_TMA];
    [self.kzDepth addItemWithTitle:FIR_GAUS];
    [self.kzDepth selectItemWithTitle:FIR_GAUS];

	// notification center
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeNotify:) name:NSWindowWillCloseNotification object:self.window];

	[self updateUserInterface];
}

- (IBAction)installHelper:(id)sender {
    [OpenBPFService installHelper];
    if (self.model) {
        [self.model openDevice];
    }
}

- (void)setInput:(BOOL)input_enabled
{
    [self.startButton setTitle:(input_enabled ? LBL_START : LBL_STOP)];
    [self.deviceSelector setEnabled:input_enabled];
    [self.filterField setEnabled:input_enabled];
    [self.promiscCheck setEnabled:input_enabled];
    [self updateUserInterface];
}

- (IBAction)startCapture:(id)sender {
	if ([self.model captureEnabled]) {
		/* stop capture */
		[self.model stopCapture];
        [self.graphView stopPlot];
        [self setInput:TRUE];
        return;
	}

    /* start capture */
    [self.model resetCounter];
    
    self.model.device = [[self.deviceSelector titleOfSelectedItem] cStringUsingEncoding:NSASCIIStringEncoding];
    self.model.filter =
    [[self.filterField stringValue] cStringUsingEncoding:NSASCIIStringEncoding];
    self.model.promisc = ([self.promiscCheck state] == NSOnState) ? YES:NO;
    if ([self.model startCapture] == FALSE) {
        [self samplingError:@"Cannot start capture thread"];
        return;
    }
    [self.graphView importData:self.model.dataBase];
    [self.graphView startPlot:TRUE];
    [self setInput:FALSE];
}

- (IBAction)changeZoom:(id)sender {
	[self.graphView setViewTimeLength:[sender floatValue]];
    [self.graphView setNeedsDisplay:YES];
	[self updateUserInterface];
}

- (IBAction)changeSmooth:(id)sender {
	[self.graphView setFIRTimeLength:[sender floatValue]];
	[self updateUserInterface];
}

- (IBAction)changeKZDepth:(id)sender {
    [self.graphView setFIRMode:[self.kzDepth titleOfSelectedItem]];
    [self.graphView setNeedsDisplay:YES];
}

- (IBAction)chnageBpsOutline:(id)sender {
    [self.graphView setUseOutline:[self.bpsOutlineEnable state]];
    [self.graphView setNeedsDisplay:YES];
}

- (IBAction)changeBPSFillMode:(id)sender {
    [self.graphView setBPSFillMode:[self.bpsFillMode titleOfSelectedItem]];
    [self.graphView setNeedsDisplay:YES];
}

- (void)zoomGesture:(id)sender
{
	float value;

	value = [self.graphView viewTimeLength];
	[self.zoomBar setFloatValue:value];
	[self updateUserInterface];
}

- (void)scrollGesture:(id)sender
{
	float value = [self.graphView FIRTimeLength];
	[self.smoothBar setFloatValue:value];
	[self updateUserInterface];
}

- (IBAction)changeRange:(id)sender {
	NSString *mode;
	float range;
	int step;

	mode = [self.rangeSelector titleOfSelectedItem];
	if (mode != RANGE_MANUAL)
		return;

	step = [self.rangeStepper intValue];
	range = [self.graphView setRange:mode withStep:step];
	NSLog(@"new range:%f", range);
	[self.rangeField setFloatValue:range];
	[self updateUserInterface];
}

- (IBAction)enterRange:(id)sender {
	NSString *mode;
	float range;

	mode = [self.rangeSelector titleOfSelectedItem];
	if (mode != RANGE_MANUAL)
		return;

	range = [self.rangeField floatValue];
	if (isnan(range) || isinf(range))
		range = 0.0f;

	range = [self.graphView setRange:mode withRange:range];
	[self.rangeField setFloatValue:range];
	[self.rangeStepper
	 setIntValue:[self.graphView stepValueFromRange:range]];
	[self updateUserInterface];
}

- (IBAction)setRangeType:(id)sender {
	NSString *mode;

	mode = [self.rangeSelector titleOfSelectedItem];
	if (mode == RANGE_MANUAL) {
		float range;

		[self.rangeField setEnabled:YES];
		[self.rangeStepper setEnabled:YES];
		range = [self.rangeField floatValue];
		range = [self.graphView setRange:mode withRange:range];
		[self.rangeField setFloatValue:range];
		return;
	}

	[self.rangeStepper setEnabled:NO];
	[self.rangeField setEnabled:NO];
	[self.graphView setRange:mode withRange:0.0f];
	[self updateUserInterface];
}

- (IBAction)togglePacketMarker:(id)sender {
	if ([sender state] == NSOnState)
		[self.graphView setShowPacketMarker:YES];
	else
		[self.graphView setShowPacketMarker:NO];

	[self.graphView setNeedsDisplay:YES];
}

- (IBAction)toggleDeviation:(id)sender {
    if ([sender state] == NSOnState) {
		[self.graphView setShowDeviationBand:YES];
        NSLog(@"deviation enabled.");
    }
    else {
		[self.graphView setShowDeviationBand:NO];
        NSLog(@"deviation disabled.");
    }

	[self.graphView setNeedsDisplay:YES];
}

- (IBAction)copyGraphView:(id)sender {
	[self.graphView saveFile:self.model.dataBase];
}

- (void)closeNotify:(NSNotification *)notify
{
    NSWindow *sender = [notify object];
    
    if (sender == self.window) {
        NSLog(@"close window. exitting..");
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [self.model stopCapture];
        [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
    }
    else {
        NSLog(@"other window was closed.");
    }
}

- (void)samplingError:(NSString *)message
{
	NSAlert *alert;

    // Reset UI
    [self.model stopCapture];
    [self.graphView stopPlot];
    [self setInput:YES];
    [self updateUserInterface];

    // Show alert dialog.
    NSLog(@"alert: %@", message);
    alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setMessageText:LBL_CAP_ERROR];
    if (message)
        [alert setInformativeText:message];
    [alert runModal];
}

- (void)updateUserInterface {
	[self.snapshotField	 setFloatValue:self.model.mbps];
	[self.maxField setFloatValue:self.model.max_mbps];
	[self.averageField setFloatValue:self.model.average_mbps];
	[self.totalpktField setIntegerValue:self.model.totalPkts];

	[self.samplingTargetField
	 setFloatValue:self.model.samplingIntervalMS];
	[self.samplingField
	 setFloatValue:self.model.samplingIntervalLastMS];
    
    [self.graphView setNeedsDisplay:YES];
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
