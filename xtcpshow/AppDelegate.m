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

#import <ServiceManagement/ServiceManagement.h>
#import <Security/Security.h>

#import "AppDelegate.h"
#import "CaptureModel.h"
#import "GraphView.h"
#import "GraphView+Draw.h"
#import "PID.h"
#import "CaptureBPF.h"
#import "OpenBPFService.h"

static NSString *const LBL_START=@"START";
static NSString *const LBL_STOP=@"STOP";
static NSString *const LBL_OK=@"OK";
static NSString *const LBL_CAP_ERROR=@"CAPTURE ERROR";

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Setup Model object
	[self setModel:[[CaptureModel alloc] init]];
	[self.model setController:self]; // weak

	// widget initialization
	[self.graphView setController:self];
	[self.graphView setShowPacketMarker:NO];
    [self.graphView setUseHistgram:NO];
	[self.graphView setMaxViewTimeLength:[self.zoomBar maxValue]];
	[self.graphView setMinViewTimeLength:[self.zoomBar minValue]];
	[self.graphView setViewTimeLength:[self.zoomBar floatValue]];
	[self.graphView setMaxFIRTimeLength:[self.smoothBar maxValue]];
	[self.graphView setMinFIRTimeLength:[self.smoothBar minValue]];
	[self.graphView setFIRTimeLength:[self.smoothBar floatValue]];
    [self.graphView createRangeButton:self.rangeSelector];
    [self.graphView createRangeButton:self.rangeSelectorCH2];
    [self.graphView createFillButton:self.bpsFillMode];
    [self.graphView createFIRButton:self.kzDepth];
    [self.graphView createFPSButton:self.fpsRate];
    [self.graphView setNeedsDisplay:YES];
    
    [self.graphViewSplit1 setController:self];
    [self.graphViewSplit1 copyConfiguration:self.graphView];
    [self.graphViewSplit1 setNeedsDisplay:YES];
    
    [self.graphViewSplit2 setController:self];
    [self.graphViewSplit2 copyConfiguration:self.graphView];
    [self.graphViewSplit2 setNeedsDisplay:YES];

    // setup intrface labels
    [self.model createInterfaceButton:self.deviceSelector];
    [self.model createInterfaceButton:self.deviceSelectorCH2];
    
	// notification center
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeNotify:) name:NSWindowWillCloseNotification object:self.window];

    [self.startButton setEnabled:TRUE];
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
        [self.graphViewSplit1 stopPlot];
        [self.graphViewSplit2 stopPlot];
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
    [self.graphViewSplit1 importData:self.model.dataBase];
    [self.graphViewSplit2 importData:self.model.dataBase];
    [self.graphView startPlot:TRUE];
    [self.graphViewSplit1 startPlot:TRUE];
    [self.graphViewSplit2 startPlot:TRUE];
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

- (IBAction)changeFPS:(id)sender {
    [self.graphView setFPSRate:[self.fpsRate titleOfSelectedItem]];
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
@end
