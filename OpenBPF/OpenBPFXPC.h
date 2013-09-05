//
//  OpenBPFXPC.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/29.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#ifndef xtcpshow_OpenBPFXPC_h
#define xtcpshow_OpenBPFXPC_h

#define OpenBPF_VERSION 1
#define BPFControlServiceID @"com.mac.hiroki.suenaga.OpenBPF"

@protocol OpenBPFXPC
- (void)alive:(void(^)(int, NSString *))block;
- (void)chown:(int)uid reply:(void(^)(BOOL, NSString *))block;
@end

#endif
