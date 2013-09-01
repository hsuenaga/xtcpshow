//
//  BPFService.m
//  xtcpshow
//
//  Created by 末永 洋樹 on 2013/09/01.
//  Copyright (c) 2013年 SUENAGA Hiroki. All rights reserved.
//
#include <sys/types.h>
#include <sys/stat.h>

#include <pcap/pcap.h>
#include <glob.h>
#include <syslog.h>

#import <Foundation/Foundation.h>
#import "BPFService.h"

static const char *const BPF_DEV="/dev/bpf*";

@implementation BPFService
- (void)alive:(void (^)(int, NSString *))block
{
	syslog(LOG_NOTICE, "alive:");
	block(OpenBPF_VERSION, @"I'm alive");
	return;
}

- (void)groupReadable:(int)uid reply:(void (^)(BOOL, NSString *))block
{
	glob_t gl;
	
	syslog(LOG_NOTICE, "groupReadble:reply:");
	
	memset(&gl, 0, sizeof(gl));
	glob(BPF_DEV, GLOB_NOCHECK, NULL, &gl);
	if (gl.gl_matchc <= 0) {
		block(NO, @"No bpf device found.");
		return;
	}
	
	for (int i = 0; i < gl.gl_pathc; i++) {
		struct stat st;
		const char *path = gl.gl_pathv[i];
		
		if (path == NULL)
			break;
		
		syslog(LOG_NOTICE, "device: %s", path);
		memset(&st, 0, sizeof(st));
		if (stat(path, &st) < 0)
			continue;
		if ((st.st_mode & S_IFCHR) == 0)
			continue;
		
		chown(path, uid, st.st_gid);
		chmod(path, st.st_mode | (S_IRUSR | S_IWUSR));
	}
	syslog(LOG_NOTICE, "/dev/bpf* are owned by UID:%d", uid);
	block(YES, @"success");
	
	return;
}
@end
