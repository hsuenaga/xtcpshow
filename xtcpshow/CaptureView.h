//
//  CaptureView.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/23.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TCPShowModel;

@interface CaptureView : NSView
@property (weak) TCPShowModel *model;
- (void)drawRect:(NSRect)rect;
@end
