//
//  DataQueueEntry.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/15.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SamplingData;

@interface DataQueueEntry : NSObject<NSCopying>
@property (strong, readonly) SamplingData *content;
@property (strong) DataQueueEntry *next;

+ (DataQueueEntry *)entryWithData:(SamplingData *)data;
- (id)copyWithZone:(NSZone *)zone;
@end
