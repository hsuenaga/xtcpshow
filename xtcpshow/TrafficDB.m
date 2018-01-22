//
//  TrafficDB.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/22.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import "TrafficDB.h"
#import "TrafficIndex.h"
#import "Queue.h"

@implementation TrafficDB
- (TrafficDB *)initWithHistorySize:(size_t)size withResolution:(NSTimeInterval)resolution startAt:(NSDate *)start endAt:(NSDate *)end
{
    self = [super initWithResolution:resolution startAt:start endAt:end];
    queue = [Queue queueWithSize:size];
    return self;
}

+ (TrafficDB *)TrafficDBWithHistorySize:(size_t)size withResolution:(NSTimeInterval)resolution startAt:(NSDate *)start endAt:(NSDate *)end
{
    return [[TrafficDB alloc] initWithHistorySize:size withResolution:resolution startAt:start endAt:end];
}

- (TrafficData *)addSampleAtTimeval:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux
{
    TrafficData *data;
    @synchronized(self) {
        NSDate *date = tv2date(tv);
        data = [super addSampleAtTimeval:tv withBytes:bytes auxData:aux];
        if (data)
            [queue enqueue:data withTimestamp:date];
        self.lastDate = date;
    }
    return data;
}

- (TrafficData *)addSampleAtTimevalExtend:(struct timeval *)tv withBytes:(NSUInteger)bytes auxData:(id)aux
{
    TrafficData *data;
    @synchronized(self) {
        data = [super addSampleAtTimevalExtend:tv withBytes:bytes auxData:aux];
    }
    return data;
}

- (BOOL)dataAtDate:(NSDate *)date withBytes:(NSUInteger *)bytes withSamples:(NSUInteger *)samples
{
    BOOL r;
    @synchronized(self) {
        r = [super dataAtDate:date withBytes:bytes withSamples:samples];
    }
    return r;
}

- (NSDate *)firstDate
{
    NSDate *date;
    
    @synchronized(self) {
        date = [queue firstDate];
    }

    return date;
}

// NSCopying protocol
- (id)copyWithZone:(NSZone *)zone
{
    TrafficDB *new = [[TrafficDB alloc] init];
    new.numberOfSamples = self.numberOfSamples;
    new.bytesReceived = self.bytesReceived;
    new.Start = self.Start;
    new.End = self.End;
    new.Resolution = self.Resolution;
    new.parent = nil;
    new->queue = [self->queue copy];
    return new;
}
@end
