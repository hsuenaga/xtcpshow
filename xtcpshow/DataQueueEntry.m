//
//  DataQueueEntry.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/15.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "DataQueueEntry.h"
#import "SamplingData.h"

@implementation DataQueueEntry
+ (DataQueueEntry *)entryWithData:(SamplingData *)data
{
	DataQueueEntry *new = [[DataQueueEntry alloc] init];

	new->_content = data;
	new->_next = nil;

	return new;
}

- (id)copyWithZone:(NSZone *)zone
{
	DataQueueEntry *new = [[DataQueueEntry alloc] init];

	new->_content = _content;
	new->_next = nil;

	return new;
}
@end
