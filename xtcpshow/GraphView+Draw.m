//
//  GraphView+Draw.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/29.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "GraphView.h"
#import "GraphView+Draw.h"
#import "PID.h"
#import "ComputeQueue.h"

@implementation GraphView (Draw)
- (void)startPlot:(BOOL)repeat
{
    if (self.cueActive)
        return;
    if (!repeat) {
        NSLog(@"One shot plot.");
        [self display];
        return;
    }
    double interval = 1.0 / self.animationFPS;
    NSLog(@"Start animiation. interval = %f [sec]", interval);
    self.timerAnimation = [NSTimer timerWithTimeInterval:interval
                                                  target:self selector:@selector(display)
                                                userInfo:nil
                                                 repeats:TRUE];
    [[NSRunLoop currentRunLoop] addTimer:self.timerAnimation
                                 forMode:NSRunLoopCommonModes];
    self.cueActive = TRUE;
}

- (void)restartPlot
{
    if (!self.cueActive)
        return;
    [self stopPlot];
    [self startPlot:TRUE];
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
    
    [self.viewData enumerateDataUsingBlock:^(id data, NSUInteger idx, BOOL *stop) {
        if (![data isKindOfClass:[GenericData class]])
            return;
        CGFloat value = (CGFloat)[data doubleValue];
        
        if (idx < self.GraphOffset)
            return;
        idx -= self.GraphOffset;
        
        if (idx > rect.size.width) {
            *stop = YES;
            return;
        }
        NSRect bar = {
            .origin = {
                .x = (CGFloat)idx,
                .y = 0
            },
            .size = {
                .width = 1.0,
                .height = value * rect.size.height / self.y_range
            }
        };
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
    BOOL __block skip = true;
    NSPoint __block plotPrev;
    [self.viewData enumerateDataUsingBlock:^(id data, NSUInteger idx, BOOL *stop) {
        if (![data isKindOfClass:[GenericData class]])
            return;
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
            NSRect histgram = {
                .origin = {
                    .x = plot.x,
                    .y = 0
                },
                .size = {
                    .width = 1.0,
                    .height = plot.y
                }
            };
            [self.gradGraph drawInRect:histgram angle:90.0];
        }
        
        // draw outline
        if (!self.useOutline && self.fillMode != E_FILL_SIMPLE)
            return;
        if (!pathOpen) {
            if (plot.y > 0.0) {
                // create new shape
                plotPrev = plot;
                skip = false;
                pathOpen = true;
                return;
            }
            [self.pathBold moveToPoint:plot];
            return;
        }
        else {
            if (plot.y == 0.0) {
                // close the shape
                //[self.pathBold lineToPoint:plot];
                [self.pathBold curveToPoint:plot
                              controlPoint1:plotPrev
                              controlPoint2:plotPrev];
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
            if (skip) {
                skip = false;
            }
            else {
                [self.pathBold curveToPoint:plot
                              controlPoint1:plotPrev
                              controlPoint2:plotPrev];
            }
            plotPrev = plot;
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
    [self.viewData enumerateDataUsingBlock:^(id data, NSUInteger idx, BOOL *stop) {
        if (![data isKindOfClass:[GenericData class]])
            return;
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
    [self.PID.outputLock lock];
    
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
    if (self.useHistgram || ![self.PID FIRenabled])
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
    
    [self.PID.outputLock unlock];
}
- (void)drawRect:(NSRect)dirty_rect
{
    if ([NSGraphicsContext currentContextDrawingToScreen]) {
        [NSGraphicsContext saveGraphicsState];
        [self.PID.outputLock lock];
        [self resampleDataInRect:self.bounds];
        [self drawAllWithSize:dirty_rect OffScreen:FALSE];
        [self.PID.outputLock unlock];
        [NSGraphicsContext restoreGraphicsState];
    }
    else {
        NSLog(@"Off Screen Rendring requested.");
        NSLog(@"w:%f, h:%f, x:%f, y:%f", dirty_rect.size.width, dirty_rect.size.height, dirty_rect.origin.x, dirty_rect.origin.y);
        [self.PID.outputLock lock];
        [self resampleDataInRect:dirty_rect];
        [self drawAllWithSize:dirty_rect OffScreen:YES];
        [self.PID.outputLock unlock];
        NSLog(@"Off Screen Rendring done.");
    }
}
@end
