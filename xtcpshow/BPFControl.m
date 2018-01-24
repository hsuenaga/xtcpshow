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
//  BPFControl.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2013/08/29.
//  Copyright (c) 2013 SUENAGA Hiroki. All rights reserved.
//
#import <sys/syslimits.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <net/bpf.h>
#import <pcap/pcap.h>
#import <glob.h>
#import <string.h>
#import <errno.h>

#import <Foundation/Foundation.h>
#import <ServiceManagement/ServiceManagement.h>
#import <SecurityFoundation/SecurityFoundation.h>
#import <Security/Security.h>

#import "BPFControl.h"
#import "OpenBPFXPC.h"

struct auth_cmsg {
    struct cmsghdr hdr;
    int fd;
};

@interface BPFControl ()
@property (assign, readwrite) uint32_t bs_recv;
@property (assign, readwrite) uint32_t bs_drop;
@property (assign, readwrite) uint32_t bs_ifdrop; // XXX: no implementation

- (BOOL)openDevice;
- (BOOL)initDevice;

// Open BPF via /usr/libexec/authopen
- (int)executeAuthopen:(NSString *)device;

// Open BPF via helper application.
- (BOOL)openXPC;
- (void)closeXPC;
- (BOOL)checkXPC;
- (void)waitXPCReply;
- (BOOL)getFileHandleXPC;
@end

@implementation BPFControl {
    // BPF device description
    NSFileHandle *deviceHandle;
    NSString *deviceName;
    int fd;
    
    // capture parameters.
    struct timeval timeout;
    uint32_t snapLen;
    BOOL promisc;

    // PCAP library
    pcap_t *pcap;
    NSString *filter_source;
    struct bpf_program filter;
    
    // XPC Helper
    BOOL xpcInvalid;
    BOOL xpcRunning;
    BOOL xpcResult;
    NSXPCConnection *xpc;
    id proxy;
    
    // packet buffer
    char *recv_buf;
    ssize_t recv_maxlen;
    char *recv_ptr;
    ssize_t recv_len;
}
@synthesize bs_recv;
@synthesize bs_drop;
@synthesize bs_ifdrop;

- (id)init
{
    self = [super init];

    // BPF device description
    deviceHandle = nil;
    deviceName = nil;
    fd = -1;

    // capture parameters.
    timeout.tv_sec = timeout.tv_usec = 0;
    snapLen = 64;
    promisc = FALSE;
    
    // PCAP library
    pcap = pcap_open_dead(DLT_EN10MB, 1500);
    if (pcap == NULL) {
        NSLog(@"Failed to create pcap instance");
        return nil;
    }
    filter_source = @"tcp";
    memset(&filter, 0, sizeof(filter));

    // XPC Helper
    xpcInvalid = FALSE;
    xpcRunning = FALSE;
    xpcResult = FALSE;
    xpc = nil;
    proxy = nil;

    // packet buffer
    recv_buf = recv_ptr = NULL;
    recv_maxlen = recv_len = 0;

    // public properties.
    self.bs_recv = 0;
    self.bs_drop = 0;
    self.bs_ifdrop = 0;

	return self;
}

- (void)dealloc
{
    if (fd >= 0)
        close(fd);
    if (pcap)
        pcap_close(pcap);
    if (filter_source)
        pcap_freecode(&filter);
    if (recv_buf)
        free(recv_buf);
}

- (BOOL)promiscus:(BOOL)flag
{
    promisc = flag;

    if (fd < 0)
        return TRUE;
    
    if (flag == true) {
        NSLog(@"Entering Promiscus mode");
        if (ioctl(fd, BIOCPROMISC, NULL) < 0) {
            NSLog(@"ioctl(BIOCPROMISC) failed: %s", strerror(errno));
            return FALSE;
        }
    }
    return TRUE;
}

- (BOOL)timeout:(const struct timeval *)interval
{
    if (interval == NULL)
        return FALSE;
    
    timeout = *interval;
    if (fd < 0)
        return TRUE;
    if (ioctl(fd, BIOCSRTIMEOUT, &timeout) < 0) {
        NSLog(@"ioctl(BIOCSRTIMEOUT) failed: %s", strerror(errno));
        return FALSE;
    }
    return TRUE;
}

- (BOOL)setSnapLen:(uint32_t)len
{
    // snaplen is a part of filter program.
    snapLen = len;
    if (pcap)
        pcap_set_snaplen(pcap, snapLen);
    
    return TRUE;
}

- (BOOL)setFilter:(NSString *)nsprog
{
    const char *prog = [nsprog UTF8String];
    
    if (filter_source) {
        pcap_freecode(&filter);
        filter_source = nil;
    }
    if (pcap_compile(pcap, &filter, prog, 1, PCAP_NETMASK_UNKNOWN) < 0) {
        NSLog(@"pcap_compile failed: %s", prog);
        NSLog(@"pcap_compile error: %s", pcap_geterr(pcap));
        return false;
    }
    filter_source = nsprog;
    
    if (fd < 0)
        return TRUE;
    if (ioctl(fd, BIOCSETFNR, &filter) < 0) {
        NSLog(@"ioctl(%d, BIOCSETFNR) failed: %s", fd, strerror(errno));
        return FALSE;
    }
    return TRUE;
}

- (BOOL)start:(const char *)source_interface
{
    struct ifreq ifr;

    if (fd < 0) {
        if (![self openDevice]) {
            NSLog(@"Cannot start capture");
            deviceName = nil;
            fd = -1;
            return false;
        }
    }
    memset(&ifr, 0, sizeof(ifr));
    if (!source_interface)
        source_interface = "pktap";

    strlcpy(ifr.ifr_name, source_interface, sizeof(ifr.ifr_name));
    
    if (ioctl(fd, BIOCSETIF, &ifr) < 0) {
        NSLog(@"ioctl(BIOCSETIF) failed: %s", strerror(errno));
        return false;
    }
    NSLog(@"BPF enabled: %@ (fd=%d)", deviceName, fd);
    return true;
}

- (BOOL)stop
{
    struct bpf_stat stat;
    
    if (fd < 0) {
        NSLog(@"No capture device");
        return false;
    }
    if (ioctl(fd, BIOCGSTATS, &stat) < 0) {
        NSLog(@"ioctl(BIOCGSTATS) failed: %s", strerror(errno));
        return false;
    }
    bs_recv = stat.bs_recv;
    bs_drop = stat.bs_drop;
    memset(recv_buf, 0, recv_maxlen);
    recv_ptr = NULL;
    recv_len = 0;
    return true;
}

- (BOOL)next: (struct timeval *)tv withCaplen:(uint32_t *)caplen withPktlen:(uint32_t *)pktlen
{
    struct bpf_hdr *hdr;
    size_t plen;

    if (recv_len < sizeof(*hdr) || recv_ptr == NULL) {
        // fetch all packets from BPF
        for (;;) {
            recv_len = read(fd, recv_buf, recv_maxlen);
            if (recv_len == 0) {
                if (tv) {
                    tv->tv_sec = 0;
                    tv->tv_usec = 0;
                }
                if (caplen)
                    *caplen = 0;
                if (pktlen)
                    *pktlen = 0;
                return true;
            }
            else if (recv_len < 0) {
                if (errno == EINTR)
                    continue;
                return false;
            }
            break;
        }
        recv_ptr = recv_buf;
    }
    
    // extract one packet from receive buffer
    hdr = (struct bpf_hdr *)recv_ptr;
    plen = BPF_WORDALIGN(hdr->bh_hdrlen + hdr->bh_caplen);
    if (recv_len < plen) {
        recv_len = 0;
        recv_ptr = NULL;
    }
    else {
        recv_len -= plen;
        recv_ptr += plen;
    }
    if (tv) {
        tv->tv_sec = hdr->bh_tstamp.tv_sec;
        tv->tv_usec = hdr->bh_tstamp.tv_usec;
    }
    if (caplen)
        *caplen = hdr->bh_caplen;
    if (pktlen)
        *pktlen = hdr->bh_datalen;
    return true;
}

+ (void)installHelper
{
    AuthorizationRef authref;
    OSStatus status;
    
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authref);
    if (status != errAuthorizationSuccess) {
        NSLog(@"AuthorizationCreate failed.");
        return;
    }
    
    //
    // Acquire Rights
    //
    AuthorizationItem authItem = {kSMRightBlessPrivilegedHelper, 0, NULL, 0};
    AuthorizationRights authRights = {1, &authItem};
    AuthorizationFlags flags = kAuthorizationFlagDefaults |
    kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize |
    kAuthorizationFlagExtendRights;
    
    status = AuthorizationCopyRights(authref, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (status != errAuthorizationSuccess) {
        NSLog(@"AuthorizationCopyRights() failed.");
        return;
    }
    
    //
    // Bless helper
    //
    CFErrorRef cfError;
    BOOL result;
    result = (BOOL)SMJobBless(kSMDomainUserLaunchd,
                              (CFStringRef)CFBridgingRetain(BPFControlServiceID),
                              authref, &cfError);
    if (!result) {
        NSError *error = CFBridgingRelease(cfError);
        NSLog(@"SMJobBless failed: %@", [error description]);
    }
    
    return;
}

- (BOOL)openDevice
{
    // close old handle
    if (fd >= 0) {
        close(fd);
        fd = -1;
        deviceName = nil;
    }
    
    // try helper
    if ([self getFileHandleXPC]) {
        NSLog(@"BPF Deivce is opened by Helper Module");
        return [self initDevice];
    }
    
    // try authopen
    glob_t gl;
    memset(&gl, 0, sizeof(gl));
    glob("/dev/bpf*", GLOB_NOCHECK, NULL, &gl);
    if (gl.gl_matchc <= 0) {
        NSLog(@"No BPF device found");
        globfree(&gl);
        return FALSE;
    }
    for (int i = ((int)gl.gl_pathc - 1); i >= 0; i--) {
        if (gl.gl_pathv[i] == NULL)
            continue;
        
        int result;
        NSString *path = [NSString stringWithUTF8String:gl.gl_pathv[i]];
        NSLog(@"Open BPF deivce via authopen: %@", path);
        result = [self executeAuthopen:path];
        switch (result) {
            case 0:
                NSLog(@"BPF Deivice opened successfully.");
                return [self initDevice];
            case ECANCELED:
                NSLog(@"Operation is canseled by user");
                return FALSE;
            default:
                break;
        }
    }
    
    NSLog(@"No BPF Deivce opened.");
    return FALSE;
}

- (BOOL)initDevice
{
    if (fd < 0) {
        NSLog(@"No BPF device opened.");
        return FALSE;
    }
    recv_maxlen = BPF_MAXBUFSIZE;
    if (ioctl(fd, BIOCSBLEN, &recv_maxlen) < 0) {
        NSLog(@"ioctl(BIOCSBLEN) failed: %s", strerror(errno));
        return FALSE;
    }
    recv_maxlen = 0;
    if (ioctl(fd, BIOCGBLEN, &recv_maxlen) < 0) {
        NSLog(@"ioctl(BIOCGBLEN) failed: %s", strerror(errno));
        return FALSE;
    }
    int param = 0;
    if (ioctl(fd, BIOCIMMEDIATE, &param) < 0) {
        NSLog(@"ioctl(BIOCIMMEDIATE) failed: %s", strerror(errno));
        return FALSE;
    }
    recv_buf = (char*)malloc(recv_maxlen);
    if (recv_buf == NULL) {
        NSLog(@"Cannot allocate receive buffer: %s", strerror(errno));
        return FALSE;
    }
    recv_ptr = NULL;
    recv_len = 0;
    
    // setup params.
    if (![self promiscus:promisc])
        return FALSE;
    if (![self timeout:&timeout])
        return FALSE;
    if (![self setSnapLen:snapLen])
        return FALSE;
    if (![self setFilter:filter_source])
        return FALSE;
    
    return TRUE;
}

- (int)executeAuthopen: (NSString *)device
{
    pid_t pid;
    int st;
    const char *cdev;
    int socks[2] = {-1, -1};
    int result = -1;
    
    if (!device) {
        NSLog(@"No device specified");
        return -1;
    }
    cdev = [device UTF8String];
    NSLog(@"Open BPF device: %s", cdev);
    if (socketpair(AF_LOCAL, SOCK_STREAM, 0, socks) < 0) {
        NSLog(@"socketpair() failed: %s", strerror(errno));
        return -1;
    }
    
    pid = fork();
    if (pid < 0) {
        NSLog(@"fork() failed: %s", strerror(errno));
        close(socks[0]);
        close(socks[1]);
        return -1;
    }
    else if (pid == 0) {
        // Child
        close(socks[0]);
        dup2(socks[1], STDOUT_FILENO);
        execl("/usr/libexec/authopen", "/usr/libexec/authopen", "-stdoutpipe", cdev, NULL);
        exit(EXIT_SUCCESS); // not reached
    }
    else {
        // Parent
        close(socks[1]);
        socks[1] = -1;
    }
    
    // Recv fd
    char msgbuf[BUFSIZ];
    struct iovec msgiov = {
        .iov_base = msgbuf,
        .iov_len = sizeof(msgbuf)
    };
    struct auth_cmsg cmsg;
    struct auth_cmsg *cmsgp;
    struct msghdr msg = {
        .msg_name = NULL,
        .msg_namelen = 0,
        .msg_iov = &msgiov,
        .msg_iovlen = 1,
        .msg_control = &cmsg,
        .msg_controllen = sizeof(cmsg),
        .msg_flags = MSG_WAITALL
    };
    ssize_t plen;
    
    NSLog(@"Wait for response from authopen...");
    for (;;) {
        plen = recvmsg(socks[0], &msg, 0);
        if (plen < 0) {
            if (errno == EINTR)
                continue;
            NSLog(@"recvmsg() failed: %s", strerror(errno));
            goto err;
        }
        break;
    }
    char *bufp;
    for (bufp = msgbuf; bufp < &msgbuf[plen];) {
        if (*bufp++ == 0x00) {
            unsigned char code = *bufp;
            
            if (bufp != &msgbuf[plen -1]) {
                NSLog(@"Unexpected '0x00' received, invalid protocol.");
                goto err;
            }
            if (code) {
                NSLog(@"authopen: code=%u(%s)", code, strerror(code));
                NSLog(@"Communication error: msg=\"%s\"", msgbuf);
                result = (int)code;
                goto err;
            }
            break;
        }
    }
    
    cmsgp = (struct auth_cmsg *)CMSG_FIRSTHDR(&msg);
    if (cmsgp == NULL) {
        NSLog(@"No control message reveiced.");
        goto err;
    }
    if (cmsgp->hdr.cmsg_len != sizeof(cmsg)) {
        NSLog(@"Unexpcted Controll message. len=%d", cmsgp->hdr.cmsg_len);
        goto err;
    }
    if (cmsgp->hdr.cmsg_level != SOL_SOCKET) {
        NSLog(@"Unexpcted Controll message. type=%d", cmsgp->hdr.cmsg_type);
        goto err;
    }
    if (cmsgp->hdr.cmsg_type != SCM_RIGHTS) {
        NSLog(@"Unexpcted Controll message. type=%d", cmsgp->hdr.cmsg_type);
        goto err;
    }
    deviceName = device;
    fd = cmsgp->fd;
    NSLog(@"BPF file descriptor received: fd=%d", fd);
    result = 0;
err:
    if (pid > 0) {
        while ((waitpid(pid, &st, 0) < 0)) {
            if (errno == EINTR)
                continue;
            NSLog(@"waitpid(%d) failed: %s", pid, strerror(errno));
        }
    }
    if (socks[0] >= 0)
        close(socks[0]);
    return result;
}

- (BOOL)openXPC
{
    if (!xpc || xpcInvalid)
    xpc = [[NSXPCConnection alloc] initWithMachServiceName:BPFControlServiceID options:NSXPCConnectionPrivileged];
    if (!xpc)
    return NO;
    
    xpcResult = NO;
    xpcInvalid = NO;
    xpcRunning = NO;
    
    xpc.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(OpenBPFXPC)];
    xpc.exportedInterface = nil;
    xpc.exportedObject = nil;
    xpc.interruptionHandler = ^(void) {
        NSLog(@"connection interrupted.");
        xpcRunning = NO;
    };
    xpc.invalidationHandler = ^(void) {
        NSLog(@"connection invalidated.");
        xpcRunning = NO;
        xpcInvalid = YES;
    };
    proxy = [xpc remoteObjectProxyWithErrorHandler:^(NSError *e) {
        NSLog(@"proxy error:%@", [e description]);
        xpcRunning = NO;
    }];
    if (proxy == nil) {
        NSLog(@"cannot get proxy");
        [xpc invalidate];
        xpc = nil;
        return NO;
    }

    [xpc resume];
    xpcRunning = YES;
    [proxy alive:^(int version, NSString *m) {
        NSLog(@"Helper livness: version %d (%@), expcted version %d",
              version, m, OpenBPF_VERSION);
        xpcResult = (version == OpenBPF_VERSION) ? YES : NO;
        xpcRunning = NO;
    }];
    [self waitXPCReply];
    if (!xpc || xpcInvalid)
        return NO;
    [xpc suspend];
    
    if (!xpcResult) {
        [xpc invalidate];
        xpc = nil;
    }
    return xpcResult;
}

- (void)closeXPC
{
    if (!xpc)
    return;
    
    [xpc invalidate];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    xpc = nil;
    xpcRunning = NO;
}

- (BOOL)checkXPC
{
    if (![self openXPC]) {
        NSLog(@"No valid helper found.");
        return NO;
    }
    
    return YES;
}

- (void)waitXPCReply
{
    // XXX: use NSLock and condition variable?
    while (xpcInvalid == NO && xpcRunning == YES) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    }
}

- (BOOL)getFileHandleXPC
{
    if ([self checkXPC] == FALSE) {
        NSLog(@"XPC Service is not found");
        return FALSE;
    }
    
    [xpc resume];
    fd = -1;
    xpcRunning = YES;
    [proxy getFileHandle:^(BOOL status, NSString *name, NSFileHandle *handle){
        xpcResult = status;
        NSLog(@"getFileHandle: => %d (%@)", status, handle);
        xpcRunning = NO;
        if (status == TRUE) {
            deviceHandle = handle;
            deviceName = name;
            fd = [handle fileDescriptor];
        }
    }];
    [self waitXPCReply];
    if (xpc) {
        [xpc suspend];
    }
    if (fd < 0)
        return FALSE;
    
    NSLog(@"messaging done: fd=%d", fd);
    return TRUE;
}
@end
