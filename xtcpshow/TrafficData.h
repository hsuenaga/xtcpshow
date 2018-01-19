// Copyright (c) 2017
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
//  TrafficData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2017/12/22.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//
#import <sys/time.h>

#import <Foundation/Foundation.h>
#import "TimeConverter.h"
// precision used by smart string representations.
#define PRECISION 1

@interface TrafficData : NSObject<NSCopying>
@property (assign, readonly, atomic, class) int newID;
@property (strong, atomic, class) NSFileHandle *debugHandle;
@property (assign, atomic) int objectID;
@property (strong, atomic) id parent;
@property (strong, atomic) id next;
@property (assign, atomic) uint64_t numberOfSamples;
@property (assign, atomic) uint64_t bytesReceived;
@property (strong, atomic) NSDate *Start;
@property (strong, atomic) NSDate *End;
@property (strong, atomic) id aux;
#pragma mark - initializer
+ (id)sampleOf:(id)parent atTimeval:(struct timeval *)tv withPacketLength:(uint64_t)length auxData:(id)aux;

#pragma mark - basic acessor
- (NSDate *)timestamp;
- (BOOL)dataAtDate:(NSDate *)date withBytes:(NSUInteger *)bytes withSamples:(NSUInteger *)samples;
- (NSUInteger)bitsAtDate:(NSDate *)date;
- (NSUInteger)bytesAtDate:(NSDate *)date;
- (NSUInteger)samplesAtDate:(NSDate *)date;

#pragma mark - simple scaled acsessor
- (NSUInteger)bytes;
- (double)kbytes;
- (double)Mbytes;
- (double)Gbytes;

- (NSUInteger)bits;
- (double)kbits;
- (double)Mbits;
- (double)Gbits;

#pragma mark - smart string representations
- (NSString *)bytesString;

#pragma mark - utility
+ (NSDate *)alignTimeval:(struct timeval *)tv withResolution:(NSTimeInterval)resolution;
- (void)alignStartEnd;
- (NSUInteger)msStart;
- (NSUInteger)msEnd;
- (void)dumpTree:(BOOL)root;
- (void)openDebugFile:(NSString *)fileName;
- (void)writeDebug:(NSString *)format, ... __attribute__((format(__NSString__, 1, 2)));
@end
