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
//  TimeConverter.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2017/12/22.
//  Copyright © 2017年 SUENAGA Hiroki. All rights reserved.
//

#ifndef TimeConverter_h
#define TimeConverter_h
#import <sys/time.h>
#import <Foundation/Foundation.h>

//
// convert NS calsses to integer[msec]
//
static inline NSUInteger
interval2msec(NSTimeInterval interval)
{
    return (NSUInteger)(floor(interval * 1.0E3));
}

static inline NSUInteger
date2msec(NSDate *date)
{
    return interval2msec([date timeIntervalSince1970]);
}

//
// convert integer[msec] to NS classes
//
static inline NSTimeInterval
msec2interval(NSUInteger msec)
{
    return (NSTimeInterval)(((double)msec) * 1.0E-3);
}

static inline NSDate *
msec2date(NSUInteger msec)
{
    return [NSDate dateWithTimeIntervalSince1970:msec2interval(msec)];
}

//
// convert Unix struct timeval to integer[msec], NS classes
//
static inline NSUInteger
tv2msec(struct timeval *tv)
{
    return tv->tv_sec * 1000 + tv->tv_usec / 1000;
}

static inline NSTimeInterval
tv2interval(struct timeval *tv)
{
    NSUInteger msec = tv2msec(tv); // ensure boundary of msec.
    
    return msec2interval(msec);
}

static inline NSDate *
tv2date(struct timeval *tv)
{
    return [NSDate dateWithTimeIntervalSince1970:tv2interval(tv)];
}

static inline void
date2tv(NSDate *date, struct timeval *tv)
{
    NSUInteger msec = date2msec(date);
    tv->tv_sec = msec / 1000;
    tv->tv_usec = (msec % 1000) * 1000;
}

#endif /* TimeConverter_h */
