//
//  BPFService.h
//  xtcpshow
//
//  Created by 末永 洋樹 on 2013/09/01.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenBPFXPC.h"

@interface BPFService : NSObject<OpenBPFXPC>
@property (strong) NSXPCConnection *xpcConnection;
@end
