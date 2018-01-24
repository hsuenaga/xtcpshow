// Copyright (c) 2013
// SUENAGA Hiroki <hiroki_suenaga@mac.com>. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.

// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

//
//  BPFControl.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/29.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#import <sys/time.h>
#import <sys/socket.h>
#import <net/if.h>
#import <pcap/pcap.h>
#import <Foundation/Foundation.h>
#import <SecurityFoundation/SecurityFoundation.h>
#import "OpenBPFXPC.h"

@interface BPFControl : NSObject
@property (assign, readonly) uint32_t bs_recv;
@property (assign, readonly) uint32_t bs_drop;
@property (assign, readonly) uint32_t bs_ifdrop; // XXX: no implementation

#pragma mark - set params
- (BOOL)promiscus:(BOOL)flag;
- (BOOL)timeout:(const struct timeval *)interval;
- (BOOL)setSnapLen:(uint32_t)len;
- (BOOL)setFilter:(NSString *)filter;

#pragma mark - start/stop
- (BOOL)start:(const char *)source_interface;
- (BOOL)stop;

#pragma mark - read received packet
- (BOOL)next: (struct timeval *)tv withCaplen:(uint32_t *)caplen withPktlen:(uint32_t *)pktlen;

#pragma mark - install priviledged helper.
+ (void)installHelper;
@end
