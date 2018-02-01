//
//  GraphView+Draw.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/29.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "GraphView.h"
@interface GraphView (Draw)
- (void)drawGraphHistgram:(NSRect)rect;
- (void)drawGraphBezier:(NSRect)rect;
- (void)drawPPS:(NSRect)rect;
- (void)drawText:(NSString *)text inRect:(NSRect)rect atPoint:(NSPoint)point;
- (void)drawText:(NSString *)text inRect:(NSRect)rect alignRight:(CGFloat)y;
- (void)drawMaxGuide:(NSRect)rect;
- (void)drawAvgGuide:(NSRect)rect;
- (void)drawGrid:(NSRect)rect;
- (void)drawRange:(NSRect)rect;
- (void)drawDate:(NSRect)rect;
- (void)drawAllWithSize:(NSRect)rect OffScreen:(BOOL)off;
- (void)setLayerContext;
- (void)drawToLayer;
- (void)drawRect:(NSRect)rect;
- (void)refreshData;
- (void)drawLayerToGC;

- (void)startPlot:(BOOL)repeat;
- (void)restartPlot;
- (void)stopPlot;
@end
