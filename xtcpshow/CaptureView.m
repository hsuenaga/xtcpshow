//
//  CaptureView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "CaptureView.h"
#import "Capture.h"

/*
 * plot bar graph
 */
void plot_mbps(NSRect rect, float mbps, float max_mbps,
	       unsigned int n, unsigned int max_n)
{
	NSBezierPath *path;
	float l, r, w, h;

	/* width and height of bar */
	w = rect.size.width / (float)max_n;
	h = rect.size.height * (mbps / max_mbps);

	/* left and right of bar */
	l = w * (float)n;
	r = l + w;
	if (r > rect.size.width)
		return;

	[[NSColor greenColor] set];
	path = [NSBezierPath bezierPath];

	[path moveToPoint:NSMakePoint(l, 0.0)];
	[path lineToPoint:NSMakePoint(l, h)];
	[path lineToPoint:NSMakePoint(r, h)];
	[path lineToPoint:NSMakePoint(r, 0.0)];
	[path closePath];
	[path fill]; /* stroke? */
}

@implementation CaptureView
- (void)drawRect:(NSRect)rect
{
	NSGraphicsContext* gc = [NSGraphicsContext currentContext];
	float mbps, max_mbps;

	mbps = [[self model] aged_mbps];
	max_mbps = [[self model] max_mbps];
	
	/* clear screen */
	[[NSColor blackColor] set];
	NSRectFill(rect);
	
	/* plot bar graph */
	{
		[gc saveGraphicsState];
		plot_mbps(rect, mbps, max_mbps, 1, 2);
		[gc restoreGraphicsState];
	}
}
@end
