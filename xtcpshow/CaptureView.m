//
//  CaptureView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "CaptureView.h"
#import "Capture.h"

@implementation CaptureView
- (void)drawRect:(NSRect)rect
{
	NSGraphicsContext* gc = [NSGraphicsContext currentContext];
	NSBezierPath *path = [NSBezierPath bezierPath];
	float mbps, ratio, x, y;
	
	NSLog(@"w=%f, h=%f", rect.size.width, rect.size.height);
	[gc saveGraphicsState];
	
	[[NSColor blackColor] set];
	NSRectFill(rect);
	
	[[NSColor greenColor] set];
	[path moveToPoint:NSMakePoint(0.0, 0.0)];
	mbps = [[self model] aged_mbps];
	ratio = mbps / 10.0; /* [%] of 10 Mbps */
	x = rect.size.height * ratio;
	y = rect.size.width * ratio;
	NSLog(@"x=%f, y=%f", x, y);
	[path lineToPoint:NSMakePoint(0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, 0)];
	[path closePath];
	[path fill];
//	[path stroke];
	
	[gc restoreGraphicsState];
}
@end
