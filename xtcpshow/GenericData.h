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
@property (readonly, atomic, class) NSUInteger newID;
@property (nonatomic, class) NSFileHandle *debugHandle;

@property (nonatomic, readonly) NSUInteger objectID;
@property (nonatomic) NSDate *dataFrom;
@property (nonatomic) NSDate *dataTo;
@property (nonatomic) double doubleValue;
@property (nonatomic) int64_t int64Value;
@property (nonatomic) uint64_t uint64Value;

#pragma mark - initializer
- (id)initWithMode:(enum enum_data_mode)mode numerator:(NSNumber *)nvalue denominator:(NSNumber *)dvalue;

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

#pragma mark - debug
+ (void)openDebugFile:(NSString *)fileName;
- (void)dumpTree:(BOOL)root;
- (void)writeDebug:(NSString *)format, ... __attribute__((format(__NSString__, 1, 2)));
@end
