//
//  GraphView+Draw.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/29.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "GraphView.h"
#import "GraphView+Draw.h"
#import "GraphViewOperation.h"
#import "DataResampler.h"
#import "ComputeQueue.h"

@implementation GraphView (Draw)
- (void)drawInBackground
{
    GraphViewOperation *op = [[GraphViewOperation alloc] initWithGraphView:self];
    [op setQueuePriority:NSOperationQueuePriorityHigh];
    [self.cueAnimation addOperation:op];
    
}

- (void)startPlot:(BOOL)repeat
{
    if (self.cueActive)
        return;
    if (!repeat) {
        NSLog(@"One shot plot.");
        [self drawInBackground];
        return;
    }
    NSLog(@"Start animiation...");
    double interval = 1.0 / self.animationFPS;
    self.timerAnimation = [NSTimer timerWithTimeInterval:interval
                                                  target:self selector:@selector(drawInBackground)
                                                userInfo:nil
                                                 repeats:TRUE];
    [[NSRunLoop currentRunLoop] addTimer:self.timerAnimation
                                 forMode:NSRunLoopCommonModes];
    self.cueActive = TRUE;
}

- (void)stopPlot
{
    if (self.cueActive) {
        NSLog(@"Stop animation...");
        [self.timerAnimation invalidate];
        self.timerAnimation = nil;
        self.cueActive = FALSE;
    }
}

//
// Graphics
//
- (void)drawGraphHistgram:(NSRect)rect
{
    [self.colorBPS set];
    
    [self.viewData enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
        NSRect bar;
        CGFloat value = (CGFloat)[data doubleValue];
        
        if (idx < self.GraphOffset)
            return;
        idx -= self.GraphOffset;
        
        if (idx > rect.size.width) {
            *stop = YES;
            return;
        }
        bar.origin.x = (CGFloat)idx;
        bar.origin.y = 0;
        bar.size.width = 1.0;
        bar.size.height = value * rect.size.height / self.y_range;
        if (bar.size.height < 1.0)
            return;
        NSRectFill(bar);
    }];
}

- (void)drawGraphBezier:(NSRect)rect
{
    [self.colorBPS set];
    
    // start from (0.0)
    NSPoint pointStart = {
        .x = 0.0, .y=0.0
    };
    [self.pathBold removeAllPoints];
    [self.pathBold moveToPoint:pointStart];
    
    // make path
    double scaler = (double)rect.size.height / (double)self.y_range;
    BOOL __block pathOpen = false;
    [self.viewData enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
        if (idx < self.GraphOffset)
            return;
        idx -= self.GraphOffset;
        
        if (idx > rect.size.width) {
            *stop = YES;
            return;
        }
        
        CGFloat value = [data doubleValue] * scaler;
        if ((int)(round(value)) == 0) {
            value = 0.0;
        }
        else if (value > rect.size.height) {
            value = rect.size.height;
        }
        NSPoint plot = {
            .x = (CGFloat)idx,
            .y = (CGFloat)value
        };
        
        // fill background
        if (self.fillMode == E_FILL_RICH && value > 0.0) {
            NSRect histgram;
            
            histgram.origin.x = plot.x;
            histgram.origin.y = 0;
            histgram.size.width = 1.0;
            histgram.size.height = plot.y;
            [self.gradGraph drawInRect:histgram angle:90.0];
        }
        
        // draw outline
        if (!self.useOutline && self.fillMode != E_FILL_SIMPLE)
            return;
        if (!pathOpen) {
            if (plot.y > 0.0) {
                // create new shape
                [self.pathBold lineToPoint:plot];
                pathOpen = true;
                return;
            }
            [self.pathBold moveToPoint:plot];
            return;
        }
        else {
            if (plot.y == 0.0) {
                // close the shape
                [self.pathBold lineToPoint:plot];
                if (self.fillMode == E_FILL_SIMPLE)
                    [self.gradGraph drawInBezierPath:self.pathBold angle:90.0];
                if (self.useOutline)
                    [self.pathBold stroke];
                
                // restart from currnet plot
                [self.pathBold removeAllPoints];
                [self.pathBold moveToPoint:plot];
                pathOpen = false;
                return;
            }
            [self.pathBold lineToPoint:plot];
            return;
        }
    }];
    
    // end at (width, 0)
    if ((self.useOutline || self.fillMode == E_FILL_SIMPLE)
        && pathOpen) {
        NSPoint pointEnd = {
            .x = rect.size.width,
            .y = 0.0
        };
        [self.pathBold lineToPoint:pointEnd];
        if (self.fillMode == E_FILL_SIMPLE)
            [self.gradGraph drawInBezierPath:self.pathBold angle:90.0];
        if (self.useOutline)
            [self.pathBold stroke];
    }
}

- (void)drawPPS:(NSRect)rect;
{
    [self.colorPPS set];
    
    double scaler = (double)rect.size.height / (double)self.pps_range;
    [self.viewData enumerateDataUsingBlock:^(DerivedData *data, NSUInteger idx, BOOL *stop) {
        if (idx < self.XmarkOffset)
            return;
        idx -= self.XmarkOffset;
        
        if (idx > rect.size.width) {
            *stop = YES;
            return;
        }
        NSUInteger samples = [data numberOfSamples];
        if (samples == 0)
            return;
        CGFloat value = (CGFloat)samples * scaler;
        [self.pathSolid removeAllPoints];
        [self.pathSolid moveToPoint:NSMakePoint((CGFloat)idx, (CGFloat)0.0)];
        [self.pathSolid lineToPoint:NSMakePoint((CGFloat)idx, value)];
        [self.pathSolid stroke];
    }];
    
    [self drawText:[NSString stringWithFormat:CAP_MAX_SMPL, self.pps_range]
            inRect:rect
           atPoint:NSMakePoint(0.0f, rect.size.height)];
}

- (void)drawMaxGuide:(NSRect)rect
{
    [self.colorMAX set];
    
    // draw line
    CGFloat value = rect.size.height * (self.maxValue / self.y_range);
    [self.pathSolid removeAllPoints];
    [self.pathSolid moveToPoint:NSMakePoint((CGFloat)0.0, value)];
    [self.pathSolid lineToPoint:NSMakePoint(rect.size.width, value)];
    [self.pathSolid stroke];
    
    // draw text
    value = [self saturateDouble:value
                         withMax:(rect.size.height / 5) * 4
                         withMin:(rect.size.height / 5)
                         roundBy:NAN];
    NSString *marker = [NSString stringWithFormat:CAP_MAX_MBPS, self.maxValue];
    [self drawText:marker inRect:rect atPoint:NSMakePoint((CGFloat)0.0, value)];
}

- (void)drawAvgGuide:(NSRect)rect
{
    [self.colorAVG set];
    
    CGFloat deviation = (CGFloat)[self.viewData standardDeviation];
    CGFloat value =    rect.size.height * (self.averageValue / self.y_range);
    
    // draw line
    [self.pathSolid removeAllPoints];
    [self.pathSolid moveToPoint:NSMakePoint(0.0, value)];
    [self.pathSolid lineToPoint:NSMakePoint(rect.size.width, value)];
    [self.pathSolid stroke];
    
    // draw band
    if (self.showDeviationBand == TRUE) {
        [self.colorDEV set];
        
        CGFloat dy = rect.size.height * (deviation / self.y_range);
        CGFloat upper = value + dy;
        if (upper > rect.size.height)
            upper = rect.size.height;
        CGFloat lower = value - dy;
        if (lower < 0.0)
            lower = 0.0;
        
        [self.pathSolid removeAllPoints];
        [self.pathSolid moveToPoint:NSMakePoint((CGFloat)0.0, upper)];
        [self.pathSolid lineToPoint:NSMakePoint((CGFloat)0.0, lower)];
        [self.pathSolid lineToPoint:NSMakePoint(rect.size.width, lower)];
        [self.pathSolid lineToPoint:NSMakePoint(rect.size.width, upper)];
        [self.pathSolid closePath];
        [self.pathSolid fill];
    }
    
    /* draw text */
    value = [self saturateDouble:value
                         withMax:(rect.size.height / 5) * 4
                         withMin:(rect.size.height / 5)
                         roundBy:NAN];
    NSString *marker = [NSString stringWithFormat:CAP_AVG_MBPS, self.averageValue, deviation];
    [self drawText:marker inRect:rect alignRight:value];
}

- (void)drawGrid:(NSRect)rect
{
    [self.colorGRID set];
    
    for (int i = 1; i < 5; i++) {
        CGFloat y = (rect.size.height / 5.0) * (CGFloat)i;
        CGFloat x = (rect.size.width / 5.0) * (CGFloat)i;
        
        // vertical line
        [self.pathDash removeAllPoints];
        [self.pathDash moveToPoint:NSMakePoint(0, y)];
        [self.pathDash lineToPoint:NSMakePoint(rect.size.width, y)];
        [self.pathDash stroke];
        
        // horizontal line
        [self.pathDash removeAllPoints];
        [self.pathDash moveToPoint:NSMakePoint(x, 0)];
        [self.pathDash lineToPoint:NSMakePoint(x, rect.size.height)];
        [self.pathDash stroke];
    }
}

- (void)drawRange:(NSRect)rect
{
    NSString *text = [NSString stringWithFormat:FMT_RANGE,
                      (self.y_range / 5.0),
                      (self.viewTimeLength /5.0) * 1.0E3,
                      self.FIRTimeLength * 1.0E3];
    [self drawText:text inRect:rect atPoint:NSMakePoint(0.0, 0.0)];
}

- (void)drawDate:(NSRect)rect;
{
    NSString *text = FMT_NODATA;
    
    if (self.viewData && ![self.viewData isEmpty])
        text = [self.dateFormatter stringFromDate:[self.viewData lastDate]];
    
    [self drawText:text inRect:rect alignRight:rect.size.height];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect atPoint:(NSPoint)point
{
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:self.textAttributes];
    NSSize size = [attrText size];
    
    if ((point.x + size.width) > rect.size.width)
        point.x = rect.size.width - size.width;
    if ((point.y + size.height) > rect.size.height)
        point.y = rect.size.height - size.height;
    
    [attrText drawAtPoint:point];
}

- (void)drawText:(NSString *)text inRect:(NSRect)rect alignRight:(CGFloat)y
{
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:self.textAttributes];
    NSSize size = [attrText size];
    
    NSPoint point = {
        .x = rect.size.width - size.width,
        .y = y,
    };
    if ((point.y + size.height) > rect.size.height)
        point.y = rect.size.height - size.height;
    [attrText drawAtPoint:point];
}

- (void)drawAllWithSize:(NSRect)rect OffScreen:(BOOL)off
{
    [self.resampler.outputLock lock];
    
    // clear screen
    [self.colorBG set];
    NSRectFill(rect);
    [self.colorFG set];
    
    // update x/y axis
    [self updateRange];
    
    // show matrix
    [self drawGrid:rect];
    
    // plot packet marker
    if (self.showPacketMarker == TRUE)
        [self drawPPS:rect];
    
    // plot bps graph
    if (self.useHistgram || ![self.resampler FIRenabled])
        [self drawGraphHistgram:rect];
    else {
        [self drawGraphBezier:rect];
    }
    
    // plot guide line (max, average, ...)
    [self drawMaxGuide:rect];
    [self drawAvgGuide:rect];
    
    /// graph params
    [self drawRange:rect];
    
    // date
    [self drawDate:rect];
    
    [self.resampler.outputLock unlock];
}

- (void)setLayerContext
{
    if (self.CGBackbuffer) {
        CGLayerRelease(self.CGBackbuffer);
        self.CGBackbuffer = NULL;
        self.NSBackbuffer = nil;
    }
    
    CGContextRef cgc = [[NSGraphicsContext currentContext] graphicsPort];
    self.CGBackbuffer = CGLayerCreateWithContext(cgc, self.bounds.size, NULL);
    
    cgc = CGLayerGetContext(self.CGBackbuffer);
    self.NSBackbuffer= [NSGraphicsContext graphicsContextWithCGContext:cgc flipped:FALSE];
    self.bgReady = FALSE;
}

- (void)drawToLayer
{
    if (!self.NSBackbuffer)
        return;
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:self.NSBackbuffer];
    [self drawAllWithSize:self.bounds OffScreen:FALSE];
    [NSGraphicsContext restoreGraphicsState];
    self.bgReady = TRUE;
}

- (void)drawLayerToGC
{
    if (!self.bgReady)
        return;
    CGContextRef cgc = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextDrawLayerAtPoint(cgc, CGPointZero, self.CGBackbuffer);
    self.bgReady = FALSE;
}

- (void)refreshData
{
    // called from GraphViewOperation
    if (self.bgReady)
        return;
    
    [self resampleDataInRect:self.lastBounds];
    [self drawToLayer];
}

- (void)drawRect:(NSRect)dirty_rect
{
    if ([NSGraphicsContext currentContextDrawingToScreen]) {
        self.lastBounds = self.bounds;
        if (self.bounds.size.width != self.resampler.outputSamples) {
            self.resampler.outputSamples = self.bounds.size.width;
            [self purgeData];
            self.bgReady = FALSE;
        }
        [self setLayerContext];
        if (self.bgReady) {
            [self drawLayerToGC];
        }
        else {
            [NSGraphicsContext saveGraphicsState];
            [self drawAllWithSize:dirty_rect OffScreen:FALSE];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
    else {
        NSLog(@"Off Screen Rendring requested.");
        NSLog(@"w:%f, h:%f, x:%f, y:%f", dirty_rect.size.width, dirty_rect.size.height, dirty_rect.origin.x, dirty_rect.origin.y);
        [self.resampler.outputLock lock];
        [self.resampler purgeData];
        self.lastResample = nil;
        [self resampleDataInRect:dirty_rect];
        [self drawAllWithSize:dirty_rect OffScreen:YES];
        [self.resampler.outputLock unlock];
        NSLog(@"Off Screen Rendring done.");
        [self purgeData];
    }
}


@end
