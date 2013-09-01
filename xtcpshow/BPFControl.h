//
//  BPFControl.h
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/29.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenBPFXPC.h"

@interface BPFControl : NSObject {
	@protected
	AuthorizationRef _authRef;
	NSXPCConnection *xpc;
	id proxy;
}

- (void)secure;
- (void)insecure;
@end