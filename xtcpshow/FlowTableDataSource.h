//
//  FlowTableDataSource.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/28.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FlowData;

@interface FlowTableDataSource : NSObject

@property(strong) FlowData *FlowData;

- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
@end