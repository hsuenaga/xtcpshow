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

@implementation BPFPacket
@synthesize timeout;
@synthesize ts;
@synthesize caplen;
@synthesize pktlen;

- (id)initWithData: (const struct timeval *)tstamp capLen:(uint32_t)clen pktLen:(uint32_t)plen
{
    self = [super init];
    if (tstamp == NULL) {
        memset(&ts, 0, sizeof(ts));
        caplen = 0;
        pktlen = 0;
        timeout = true;
    }
    else {
        memcpy(&ts, tstamp, sizeof(ts));
        caplen = clen;
        pktlen = plen;
        timeout = false;
    }
    return self;
}

- (id)initWithoutData
{
    return [self initWithData:NULL capLen:0 pktLen:0];
}

- (id)init
{
    return [self initWithoutData];
}

- (const struct timeval *)ts_ref
{
    return (const struct timeval *)&ts;
}
@end

@implementation BPFControl
@synthesize fd;
@synthesize bs_recv;
@synthesize bs_drop;

- (id)initWithDevice: (NSString *)device
{
    self = [super init];
    fd = -1;
    if ([self _openBpf:device] < 0) {
        NSLog(@"Failed to open BPF.");
        return nil;
    }
    
    // allocate dummy pcap for filter progaram compilation.
    // we cannot use live caputure mode due to permission.
    pcap = pcap_open_dead(DLT_EN10MB, 1500);
    if (pcap == NULL) {
        NSLog(@"Failed to create pcap instance");
        return nil;
    }
    
    if (fd >= 0) {
        // setup BPF buffer.
        int off = 0;
        recv_maxlen = BPF_MAXBUFSIZE;
        if (ioctl(fd, BIOCSBLEN, &recv_maxlen) < 0) {
            NSLog(@"ioctl(BIOCSBLEN) failed: %s", strerror(errno));
        }
        if (ioctl(fd, BIOCGBLEN, &recv_maxlen) < 0) {
            NSLog(@"ioctl(BIOCGBLEN) failed: %s", strerror(errno));
        }
        if (ioctl(fd, BIOCIMMEDIATE, &off) < 0) {
            NSLog(@"ioctl(BIOCIMMEDIATE) failed: %s", strerror(errno));
        }
        recv_buf = (char *)malloc(recv_maxlen);
        recv_ptr = NULL;
        recv_len = 0;
    }
    filter_source = NULL;
	return self;
}

- (id)init
{
    return [self initWithDevice:nil];
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

- (int)_openBpf: (NSString *)device
{
    if (device) {
        //    if (![self _obtain_rights:device])
        //        return -1;
        [self _obtain_fd:device];
      }
    else {
        for (int idx = 4; idx >= 0; idx--) {
            device = [[NSString alloc] initWithFormat:@"/dev/bpf%d", idx];
            if ([self _obtain_fd:device])
                break;
        }
    }
    return fd;
}

#if 0
- (bool)_obtain_rights: (NSString *)device
{
    // Configure requested authorization.
    char auth_spec[PATH_MAX + strlen("sys.openfile.readwritecreate.")];
    
    sprintf(auth_spec, "sys.openfile.readonly.%s", [device UTF8String]);
    AuthorizationFlags auth_flags = kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagExtendRights |
    kAuthorizationFlagPreAuthorize;
    
    // Show Authentication dialog
    NSError *error = nil;
    self->_authObj = [SFAuthorization authorization];
    if (![self->_authObj obtainWithRight:auth_spec
                                   flags:auth_flags
                                   error:&error]) {
        NSLog(@"Failed to obtain Right");
        return false;
    }
    
    // Serialize the right object
    self->_authRef = [self->_authObj authorizationRef];
    OSStatus result = AuthorizationMakeExternalForm(self->_authRef, &self->_authRefExt);
    if (result != errAuthorizationSuccess) {
        NSLog(@"Failed to serialize AuthorizationRef (%d)", result);
        return false;
    }
    return true;
}
#endif

- (bool)_obtain_fd: (NSString *)device
{
    pid_t pid;
    int st;
    const char *cdev;
    int socks[2] = {-1, -1};
    BOOL result = false;
    
    if (!device) {
        NSLog(@"No device specified");
        return false;
    }
    cdev = [device UTF8String];
    NSLog(@"Open BPF device: %s", cdev);
    if (socketpair(AF_LOCAL, SOCK_STREAM, 0, socks) < 0) {
        NSLog(@"socketpair() failed: %s", strerror(errno));
        return false;
    }

    pid = fork();
    if (pid < 0) {
        NSLog(@"fork() failed: %s", strerror(errno));
        close(socks[0]);
        close(socks[1]);
        return false;
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
    fd = cmsgp->fd;
    NSLog(@"BPF file descriptor received: fd=%d", fd);
    result = true;
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

- (BOOL)promiscus:(BOOL)flag
{
    if (flag == true) {
        NSLog(@"Entering Promiscus mode");
        if (ioctl(fd, BIOCPROMISC, NULL) < 0) {
            NSLog(@"ioctl(BIOCPROMISC) failed: %s", strerror(errno));
            return false;
        }
    }
    return true;
}

- (BOOL)timeout:(const struct timeval *)interval
{
    if (ioctl(fd, BIOCSRTIMEOUT, interval) < 0) {
        NSLog(@"ioctl(BIOCSRTIMEOUT) failed: %s", strerror(errno));
        return false;
    }
    return true;
}

- (BOOL)setSnapLen:(uint32_t) len
{
    // snaplen is a part of filter program.
    if (pcap)
        pcap_set_snaplen(pcap, len);
    
    return true;
}

- (BOOL)start:(const char *)source_interface
{
    struct ifreq ifr;

    memset(&ifr, 0, sizeof(ifr));
    if (!source_interface)
        source_interface = "pktap";

    strlcpy(ifr.ifr_name, source_interface, sizeof(ifr.ifr_name));
    
    if (ioctl(fd, BIOCSETIF, &ifr) < 0) {
        NSLog(@"ioctl(BIOCSETIF) failed: %s", strerror(errno));
        return false;
    }
    
    return true;
}

- (BOOL)stop
{
    struct bpf_stat stat;
    
    if (ioctl(fd, BIOCGSTATS, &stat) < 0) {
        NSLog(@"ioctl(BIOCGSTATS) failed: %s", strerror(errno));
        return false;
    }
    bs_recv = stat.bs_recv;
    bs_drop = stat.bs_drop;
    return true;
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
    if (ioctl(fd, BIOCSETFNR, &filter) < 0) {
        NSLog(@"ioctl(%d, BIOCSETFNR) failed: %s", fd, strerror(errno));
        return false;
    }
    filter_source = nsprog;
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

- (BPFPacket *)nextPacket
{
    struct timeval tv;
    uint32_t caplen, pktlen;

    if ([self next:&tv withCaplen:&caplen withPktlen:&pktlen])
        return [[BPFPacket alloc] initWithoutData];

    return [[BPFPacket alloc] initWithData:&tv capLen:caplen pktLen:pktlen];
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
@end
