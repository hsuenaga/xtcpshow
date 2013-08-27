//
//  FlowData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/26.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlowData : NSObject
{
	NSMapTable *FlowIDToRec;
	NSMapTable *FlowRecToID;
	NSMapTable *FlowRecToState;
	int lastClassID;
}
- (int)clasifyPacket:(const void *)byte size:(size_t)size linkType:(int)dlt;
- (NSString *)descriptionForClassID:(int)classID;
@end
