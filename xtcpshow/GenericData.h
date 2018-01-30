//
//  GenericData.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/30.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>

enum enum_data_mode {
    DATA_NOVALUE,
    DATA_DOUBLE,
    DATA_INTEGER,
    DATA_UINTEGER,
    DATA_FRACTION
};

@interface GenericData : NSObject<NSCopying>
@property NSDate *dataFrom;
@property NSDate *dataTo;
@property NSUInteger numberOfSamples;
@property (nonatomic, readonly) double doubleValue;
@property (nonatomic, readonly) int64_t int64Value;
@property (nonatomic, readonly) uint64_t uint64Value;

#pragma mark - allocator
+ (id)dataWithoutValue;
+ (id)dataWithDouble:(double)data;
+ (id)dataWithInteger:(NSInteger)data;
+ (id)dataWithUInteger:(NSUInteger)data;
+ (id)dataWithFraction:(NSInteger)numerator denominator:(NSInteger)denominator;

#pragma mark - accessor
- (void)addInteger:(NSInteger)value;
- (void)addFracNumerator:(NSInteger)value;
- (void)divInteger:(NSInteger)value;
- (void)mulInteger:(NSInteger)value;
- (void)addData:(GenericData *)data;
- (void)simplifyFraction;
@end
