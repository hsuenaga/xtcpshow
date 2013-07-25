//
//  GraphView.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "GraphView.h"
#import "GraphData.h"

static void plot_mbps(NSRect, float, float,
		      unsigned int, unsigned int);
static void plot_trend(NSRect, float, float);

/*
 * plot bar graph
 */
static void plot_mbps(NSRect rect, float mbps, float max_mbps,
		      unsigned int n, unsigned int max_n)
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	float l, r, w, h;

	/* width and height of bar */
	w = rect.size.width / (float)max_n;
	h = rect.size.height * (mbps / max_mbps);
	if (h < MIN_FILTER)
		return;

	/* left and right of bar */
	l = w * (float)n;
	r = l + w;
	if (r > rect.size.width)
		return;

	[[NSColor greenColor] set];
//	[path setLineWidth:(3.0)];
	[path moveToPoint:NSMakePoint(l, 0.0)];
	[path lineToPoint:NSMakePoint(l, h)];
	[path stroke];
//	NSRectFill(NSMakeRect(l, 0.0, w, h));
//	[path moveToPoint:NSMakePoint(l, 0.0)];
//	[path lineToPoint:NSMakePoint(l, h)];
//	[path lineToPoint:NSMakePoint(r, h)];
//	[path lineToPoint:NSMakePoint(r, 0.0)];
//	[path closePath];
//	[path fill];
}

static void plot_trend(NSRect rect, float mbps, float max_mbps)
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	float y;
	
	[[NSColor redColor] set];
	y = rect.size.height * (mbps / max_mbps);
	[path moveToPoint:NSMakePoint(0.0, y)];
	[path lineToPoint:NSMakePoint(rect.size.width, y)];
	[path stroke];
}

@implementation GraphView
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
}

- (void)drawRect:(NSRect)rect
{
	NSGraphicsContext* gc = [NSGraphicsContext currentContext];
	NSString *title;
	NSMutableDictionary *attr;
	float res, max_mbps;
	__block float avg_mbps;
	__block int winsz;
	int smasz;

	
	NSDisableScreenUpdates();
	res = self->resolution * 1000.0; // [ms]

	/* clear screen */
	[[NSColor blackColor] set];
	NSRectFill(rect);
	
	/* plot bar graph */
	avg_mbps = 0.0;
	winsz = self->window_size;
	smasz = self->sma_size;
	max_mbps = [self->data maxWithItems:winsz withSMA:smasz];
	[self->data blockForEach:^(float value, int i) {
		avg_mbps += value;
		[gc saveGraphicsState];
		plot_mbps(rect, value, max_mbps, i, winsz);
		[gc restoreGraphicsState];
		return 0;
	} WithItems:winsz WithSMA:smasz];
	if ([self->data size] > 0)
		avg_mbps = avg_mbps / (float)[self->data size];
	else
		avg_mbps = 0.0;
	
	/* bar graph params */
	title =
	[NSString stringWithFormat:@" MAX %3.3f [Mbps] / AVG %3.3f [Mbps] / Scale %2.1f [ms] / SMA %2.1f [ms]",
	 max_mbps, avg_mbps, (res * winsz), (res * smasz)];
	attr = [[NSMutableDictionary alloc] init];
	[attr setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[attr setValue:[NSFont fontWithName:@"Menlo Regular" size:14] forKey:NSFontAttributeName];
	[title drawAtPoint:NSMakePoint(0.0, 0.0) withAttributes:attr];

	/* plot trend line */
	plot_trend(rect, avg_mbps, max_mbps);
	
	NSEnableScreenUpdates();
}

- (void)addSnap:(float)snap trendData:(float)trend resolusion:(float)res
{
	self->snap_mbps = snap;
	self->trend_mbps = trend;
	self->resolution = res;
	
	/* delegate to history store */
	[self->data addFloat:snap];
}
@end
