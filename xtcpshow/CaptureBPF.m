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
//  CaptureBPF.m
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

#import "CaptureBPF.h"
#import "OpenBPFService.h"
#import "authopenBPF.h"

@interface CaptureBPF ()
@property (assign, readwrite) uint32_t bs_recv;
@property (assign, readwrite) uint32_t bs_drop;
@property (assign, readwrite) uint32_t bs_ifdrop; // XXX: no implementation

- (BOOL)initDevice;
@end

@implementation CaptureBPF {
    // BPF device description
    OpenBPFService *bpfService;
    authopenBPF *bpfAuthopen;
    int fd;
    
    // capture parameters.
    struct timeval timeout;
    uint32_t snapLen;
    BOOL promisc;

    // PCAP library
    pcap_t *pcap;
    NSString *filter_source;
    struct bpf_program filter;
    
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
    bpfService = [[OpenBPFService alloc] init];
    bpfAuthopen = [[authopenBPF alloc] init];
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
        NSLog(@"BPF device is not initialized.");
        return false;
    }
    memset(&ifr, 0, sizeof(ifr));
    if (!source_interface)
        source_interface = "pktap";

    strlcpy(ifr.ifr_name, source_interface, sizeof(ifr.ifr_name));
    
    if (ioctl(fd, BIOCSETIF, &ifr) < 0) {
        NSLog(@"ioctl(BIOCSETIF) failed: %s", strerror(errno));
        return false;
    }
    NSLog(@"BPF enabled: (fd=%d)", fd);
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

- (BOOL)openDevice
{
    // close old handle
    if (fd >= 0) {
        [bpfService closeDevice];
        [bpfAuthopen closeDevice];
        fd = -1;
    }
    
    // try helper
    if ([bpfService openDevice]) {
        NSLog(@"BPF Device is opened by Helper Module");
        fd = [bpfService fileDescriptor];
        return [self initDevice];
    }
    
    // try authopen
    if ([bpfAuthopen openDevice]) {
        NSLog(@"BPF Device is opened by authopen");
        fd = [bpfAuthopen fileDescriptor];
        return [self initDevice];
    }
    
    NSLog(@"No BPF Deivce opened.");
    return FALSE;
}

- (void)closeDevice
{
    if (fd < 0)
        return;
    [bpfService closeDevice];
    [bpfAuthopen closeDevice];
    fd = -1;
    return;
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

@end
