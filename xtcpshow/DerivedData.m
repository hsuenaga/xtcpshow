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
//  DerivedData.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/09.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//

#import "DerivedData.h"

@implementation DerivedData
+ (id)dataWithoutSample
{
	DerivedData *new = [[[self class] alloc] init];
	new->_timestamp = [NSDate date];

	return new;
}

+ (id)dataWithSingleFloat:(float)data
{
	DerivedData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithFloat:data];
	new->_timestamp = [NSDate date];
	new->_numberOfSamples = 1;

	return new;
}

+ (id)dataWithSingleInt:(int)data
{
	DerivedData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithInt:data];
	new->_timestamp = [NSDate date];
	new->_numberOfSamples = 1;

	return new;
}

+ (id)dataWithFloat:(float)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples;
{
	DerivedData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithFloat:data];
	new->_timestamp = [date copy];
	new->_numberOfSamples = samples;

	return new;
}

+ (id)dataWithInt:(int)data atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
	DerivedData *new = [[[self class] alloc] init];

	new->_number = [NSNumber numberWithInt:data];
	new->_timestamp = date;
	new->_numberOfSamples = samples;

	return new;
}

+ (id)dataWithNumber:(NSNumber *)number atDate:(NSDate *)date fromSamples:(NSUInteger)samples
{
	DerivedData *new = [[[self class] alloc] init];

	new->_number = number;
	new->_timestamp = date;
	new->_numberOfSamples = samples;

	return new;
}

- (float)floatValue
{
	return [_number floatValue];
}

- (int)intValue
{
	return [_number intValue];
}

- (id)copyWithZone:(NSZone *)zone
{
	DerivedData *new = [[DerivedData alloc] init];

	new->_number = [_number copy];
	new->_timestamp = [_timestamp copy];
	new->_numberOfSamples = _numberOfSamples;

	return new;
}

- (void)invalidTimeException
{
	NSException *ex = [NSException exceptionWithName:@"Invalid Time" reason:@"Invalid Time in DataEntry" userInfo:nil];

	@throw ex;
}
@end
