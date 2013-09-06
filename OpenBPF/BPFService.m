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
//  BPFService.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/09/01.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
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

- (void)chown:(int)uid reply:(void (^)(BOOL, NSString *))block
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
