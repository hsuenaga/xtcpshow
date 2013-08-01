//
//  GraphView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include "math.h"

#import "GraphView.h"
#import "GraphData.h"

@implementation GraphView
- (void)allocGraphImage
{
	image_size = [self bounds].size;
	image_rep = [[NSBitmapImageRep alloc]
		 initWithBitmapDataPlanes:NULL
		 pixelsWide:image_size.width
		 pixelsHigh:image_size.height
		 bitsPerSample:8
		 samplesPerPixel:4
		 hasAlpha:YES
		 isPlanar:NO
		 colorSpaceName:NSDeviceRGBColorSpace
		 bitmapFormat:NSAlphaFirstBitmapFormat
		 bytesPerRow:0
		 bitsPerPixel:0];
	image = [[NSImage alloc] initWithSize:image_size];
	[image addRepresentation:image_rep];
	
	backbuffer_rep = [[NSBitmapImageRep alloc]
		     initWithBitmapDataPlanes:NULL
		     pixelsWide:image_size.width
		     pixelsHigh:image_size.height
		     bitsPerSample:8
		     samplesPerPixel:4
		     hasAlpha:YES
		     isPlanar:NO
		     colorSpaceName:NSDeviceRGBColorSpace
		     bitmapFormat:NSAlphaFirstBitmapFormat
		     bytesPerRow:0
		     bitsPerPixel:0];
	backbuffer = [[NSImage alloc] initWithSize:image_size];
	[backbuffer addRepresentation:backbuffer_rep];
	
	needRedrawAll = TRUE;
}

- (void)clearGraphImage
{
	NSRect rect;
	NSGraphicsContext *gc;

	[NSGraphicsContext saveGraphicsState];
	
	rect.origin = NSMakePoint(0.0, 0.0);
	rect.size = image_size;
	
	gc= [NSGraphicsContext graphicsContextWithBitmapImageRep:image_rep];
	if (gc == nil)
		NSLog(@"No graph iamge");
	[NSGraphicsContext setCurrentContext:gc];
	[[NSColor clearColor] set];
	NSRectFill(rect);
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)redrawGraphImage
{
	__block float sum = 0.0;

	[NSGraphicsContext saveGraphicsState];
	[self->data forEach:^(float value, int w) {
		sum += value;
		[self plotBPS:value
		       maxBPS:y_range
			atPos:w
		       maxPos:image_size.width];
		return 0;
	} withRange:window_size withWidth:image_size.width];
	view_avg_mbps = sum / image_size.width;

	needRedrawImage = FALSE;
	[NSGraphicsContext restoreGraphicsState];
}

- (void)updateRange
{
	float new_range;
	float unit;

	/* auto ranging */
	view_max_mbps = [self->data maxWithRange:window_size];

	if (view_max_mbps < 1.0) {
		unit = 1.0;
	}
	else if (view_max_mbps < 5.0) {
		unit = 2.5;
	}
	else {
		unit = 5.0;
	}
	
	new_range = (unit * (floor(view_max_mbps / unit) + 1.0));
	if (new_range != y_range) {
		needRedrawImage = TRUE;
	}
	y_range = new_range;
	x_range = resolution * window_size; // [ms]
}

- (void)drawText: (NSString *)t atPoint:(NSPoint) p
{
	NSMutableDictionary *attr;
	
	attr = [[NSMutableDictionary alloc] init];
	[attr setValue:[NSColor whiteColor]
		forKey:NSForegroundColorAttributeName];
	[attr setValue:[NSFont fontWithName:@"Menlo Regular" size:12]
		forKey:NSFontAttributeName];
	[t drawAtPoint:p withAttributes:attr];
}

- (void)plotBPS:(float)mbps
	 maxBPS:(float)max_mbps
	  atPos:(unsigned int)n
	 maxPos:(int)max_n
{
	NSGradient *grad;
	NSRect bar, rect;
	float l, r, w, h;

	
	rect = [self bounds];
	
	/* width and height of bar */
	h = floor(rect.size.height * (mbps / max_mbps));
	if (h < 1.0)
		return; // less than 1 pixel
	w = floor(rect.size.width / (float)max_n);
	if (w < 1.0)
		w = 1.0;
	
	/* left and right of bar */
	l = floor(w * (float)n);
	r = floor(l + w);
	if (r > rect.size.width)
		return;
	
	bar.origin.x = l;
	bar.origin.y = 0;
	bar.size.width = w + 1.0;
	bar.size.height = h;
	
	grad = [[NSGradient alloc]
		initWithStartingColor:[NSColor clearColor]
		endingColor:[NSColor greenColor]];
	[grad drawInRect:bar angle:90.0];
}

- (void)plotTrend
{
	NSRect rect;
	NSBezierPath *path;
	NSString *marker;
	float y;
	
	[NSGraphicsContext saveGraphicsState];
	
	rect = [self bounds];

	[[NSColor redColor] set];
	path = [NSBezierPath bezierPath];
	y = rect.size.height * (view_avg_mbps / y_range);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
	
	[[NSColor blueColor] set];
	path = [NSBezierPath bezierPath];
	y = rect.size.height * (view_max_mbps / y_range);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
	
	/* max maker */
	if (y < (rect.size.height / 5))
		y = (rect.size.height / 5);
	else if (y > ((rect.size.height / 5) * 4))
		y = (rect.size.height / 5) * 4;
	
	marker = [NSString stringWithFormat:@" Max %6.3f", view_max_mbps];
	[self drawText:marker atPoint:NSMakePoint(0.0, y)];
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)allocHist
{
	self->data = [[GraphData alloc] init];
	if (self->data == nil)
		NSLog(@"cannot alloc history");
	[self->data setBufferSize:DEF_BUFSIZ];
}

- (void)setWindowSize:(int)size
{
	window_size = size;
	
	if (window_size < 10)
		window_size = 10;
	else if (window_size > [self->data size])
		window_size = [self->data size];
}

- (void)setSMASize:(int)size
{
	sma_size = size;
	if (sma_size < 1)
		sma_size = 1;
	else if (sma_size > [self->data size])
		sma_size = [self->data size];

	[self updateRange];
	needRedrawImage = TRUE;
}

- (void)drawAll
{
	NSRect rect = [self bounds];
	NSString *title;
	int smasz;

	[NSGraphicsContext saveGraphicsState];

	/* clear screen */
	[[NSColor clearColor] set];
	NSRectFill(rect);
	
	/* caclulate size */
	smasz = self->sma_size;
	[self->data setSMASize:sma_size];
	
	/* show matrix */
	[[NSColor whiteColor] set];
	for (int i = 1; i < 5; i++) {
		CGFloat pattern[2] = {5.0, 5.0};
		NSBezierPath *path;
		float y = (rect.size.height / 5.0) * (float)i;
		
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(0, y)];
		[path lineToPoint:NSMakePoint(rect.size.width, y)];
		[path stroke];
	}
	for (int i = 1; i < 5; i++) {
		CGFloat pattern[2] = {5.0, 5.0};
		NSBezierPath *path;
		float x = (rect.size.width / 5.0) * (float)i;
		
		path = [NSBezierPath bezierPath];
		[path setLineDash:pattern count:2 phase:0.0];
		[path moveToPoint:NSMakePoint(x, 0)];
		[path lineToPoint:NSMakePoint(x, rect.size.height)];
		[path stroke];
	}
	
	/* plot bar graph */
	[self redrawGraphImage];
	
	/* bar graph params */
	title =
	[NSString stringWithFormat:@" Y-Range %6.3f [Mbps] / X-Range %6.1f [ms] / SMA %6.1f [ms] / Avg %6.3f [Mbps] ",
	 y_range, x_range, (resolution * smasz), view_avg_mbps];
	[self drawText:title atPoint:NSMakePoint(0.0, 0.0)];
	
	/* plot trend line */
	[self plotTrend];
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)dirty_rect
{
	if (image == nil)
		return;
	if (backbuffer == nil)
		return;
	
	NSDisableScreenUpdates();
	if (needRedrawAll)
		[self drawAll];
	NSEnableScreenUpdates();
}

- (void)addSnap:(float)snap trendData:(float)trend resolusion:(float)res
{
	self->snap_mbps = snap;
	self->trend_mbps = trend;
	self->resolution = res;
	
	/* delegate to history store */
	[self->data addFloat:snap];
	[self updateRange];
	needRedrawImage = TRUE;
	needRedrawAll = TRUE;
}
@end
