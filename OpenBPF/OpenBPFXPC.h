//
//  OpenBPFXPC.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/29.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#ifndef xtcpshow_OpenBPFXPC_h
#define xtcpshow_OpenBPFXPC_h

@protocol OpenBPFXPC
- (void)groupReadable:(int)uid reply:(void(^)(BOOL, NSString *))block;
- (void)alive:(void(^)(BOOL, NSString *))block;
@end

#endif
