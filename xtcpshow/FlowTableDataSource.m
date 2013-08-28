//
//  FlowTableDataSource.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/28.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import "FlowTableDataSource.h"
#import "FlowData.h"

@implementation FlowTableDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView
{
	return [_FlowData numberOfClassID];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSArray *array = [_FlowData arrayOfClassID];
	NSNumber *classID = [array objectAtIndex:row];

	if ([[tableColumn identifier] isEqualToString:@"ID"]) {
		return [classID stringValue];
	} else {
		return [_FlowData descriptionForClassID:[classID intValue]];
	}
}
@end
