//
//  TrafficDB.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/22.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrafficIndex.h"

@class Queue;

@interface TrafficDB : TrafficIndex {
    Queue *queue;
}
@property (assign, readonly) size_t hitorySize;

- (TrafficDB *)initWithHistorySize:(size_t)size withResolution:(NSTimeInterval)resolution startAt:(NSDate *)start endAt:(NSDate *)end;
+ (TrafficDB *)TrafficDBWithHistorySize:(size_t)size withResolution:(NSTimeInterval)resolution startAt:(NSDate *)start endAt:(NSDate *)end;

- (NSDate *)firstDate;
@end
