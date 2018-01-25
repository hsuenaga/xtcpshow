//
//  authopenBPF.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/25.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface authopenBPF : NSObject
@property (assign, readonly) int fileDescriptor;
@property (strong, readonly) NSString *deviceName;

- (BOOL)openDevice;
- (void)closeDevice;
@end
