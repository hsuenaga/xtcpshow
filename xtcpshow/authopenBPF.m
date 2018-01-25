//
//  authopenBPF.m
//  xtcpshow
//
//  Created by SUENAGA Hiroki on 2018/01/25.
//  Copyright © 2018年 SUENAGA Hiroki. All rights reserved.
//
#import <sys/socket.h>
#import <glob.h>

#import "authopenBPF.h"

struct auth_cmsg {
    struct cmsghdr hdr;
    int fd;
};

@interface authopenBPF ()
@property (assign) int fileDescriptor;
@property (strong) NSString *deviceName;
@end

@implementation authopenBPF

- (BOOL)openDevice
{
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
                globfree(&gl);
                return TRUE;
            case ECANCELED:
                NSLog(@"Operation is canseled by user");
                globfree(&gl);
                return FALSE;
            default:
                break;
        }
    }
    globfree(&gl);
    return FALSE;
}

- (void)closeDevice
{
    if (self.fileDescriptor >= 0) {
        close(self.fileDescriptor);
        self.fileDescriptor = -1;
        self.deviceName = nil;
    }
    return;
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
    self.fileDescriptor = cmsgp->fd;
    self.deviceName = device;
    NSLog(@"BPF file descriptor received: fd=%d", self.fileDescriptor);
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
@end
