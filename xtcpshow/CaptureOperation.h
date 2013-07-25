//
//  CaptureOperation.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/07/19.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <pcap/pcap.h>

#import <Foundation/Foundation.h>
#import "AppDelegate.h"

#define TIMESLOT (0.05) /* [sec] */
#define AGESLOT (1.0) /* [sec] */

@class CaptureModel;

@interface CaptureOperation : NSOperation
@property (weak) CaptureModel *model;
- (void)main;
@end