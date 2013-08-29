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
- (void)secure;
- (void)insecure;
@end

@protocol NotifyOpenBPFXPC
- (void)XPCresult:(BOOL)result;
@end

#endif
