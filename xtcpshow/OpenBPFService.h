//
//  OpenBPFService.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/25.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "OpenBPFXPC.h"

@interface OpenBPFService : NSObject
@property (assign, atomic, readonly) int version;
@property (strong, atomic, readonly) NSString *message;
@property (assign, atomic, readonly) BOOL status;
@property (strong, atomic, readonly) NSString *deviceName;
@property (strong, atomic, readonly) NSFileHandle *deviceHandle;

+ (void)installHelper;
- (BOOL)openDevice;
- (void)closeDevice;
- (int)fileDescriptor;
@end
