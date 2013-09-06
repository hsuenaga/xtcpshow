xtcpshow
========

A Network Traffic Grapher for Mac OS X
--------------------------------------

![ScreenShot](./xtcpshow_screen.png)

HOW TO USE
----------

1. launch the application
2. selelct your network interface
2. press "START" button

### launch the application

Simply launch the application from Dock, Finder, etc. The application doen't need administrator priviledge on starting.

### select your network interface

1. Select "Config" tab on the top of window
2. Select your favorite network interface(en0, en1, ppp0, ...) from combo-box at the top-right
3. If you want show the packet which doen't toward to your Mac, check "Promiscuous" check-button. If promiscuous mode was enabled on broadcast network interface(i.e. Ethernet), all packet on the wire are received by the interface. If not, only packets for your Mac are received. The promiscuous mode can cause a serious CPU load in your Mac. If your Mac seems not responding, try the interface to be disconnected.

### press START button

1. On START button cliked, the application try to open /dev/bpf, the Berkley Packet Filtering device.
2. /dev/bpf has restrected premission to open. If your system configured to need administrator(root) privilege on /dev/bpf (this is factory default), the application prompt you to enter password to install priviledged helper tool into /Library/PrivilegedHelperTools. There are some applications that changes permission of /dev/bpf. For example, some version of wireshark create UNIX group 'access_bpf' and set /dev/bpf group readable/wriable. In such case, the application doen't prompt your password.
3. If everythings OK, the application shows traffic graph.

Configure the view
------------------

### Mbps calculation

Traffic sampling logic of the application is on the following.

1. Caputer a packet on /dev/bpf and record the bytes received and time stamp.
2. Calculate triangle moving average for the bytes received.
3. Calculate mbps of the averaged bytes received.

### Range of the View

The X-axis(time[msec]) range can be controlled by horizontal scroll bar. Y-axis([Mbps]) is controlled automatically by default. You can change this behavior by 'Range Select' combo-box in Config tab. 'Auto' mode controlls the Y-axis automatically. 'Peak-Hold' mode also controlls the Y-axis automatically, but it only increase the range. On 'Manual' mode, the range is controlled by the user input of text box. The range value is always rounded by times of 5.

### Triangle Moving Average

The application calculate the viewing bytes received at time t (vbytes[t]) as average of captured bytes(cbytes[t]) for last MA[sec]. For exapmle, vbytes[t0] = Avg(cbytes[t0] .. cbytes[t0 - MA]). you can configure the value of MA by vertical slider.

The lesser MA shows accurate timing of the packet. And the lesser MA will have been resemling the differentials of the traffic. If MA was 0, the mbps become infinity. The more MA shows integral of the traffic(on the other words, the more MA is worked as same as low pass filter).

### Packet histgram

You can show a histgram of the number of packets received by checking 'packets/sample' check-box in Config tab. The hisgram was shown in cyan color and overlayed on the mbps graph. The phase of this histgram and moving average are synchronized automatically.

### Mbps distribution(deviation)

You can show a standard deviation band by checking 'deviation' check-box. If the distrubition of traffic seems to a normal distribution, this band may become a some help you. The distribution of enough multiplexed traffic may be a normal distribution, but I think most of traffics are not.

Uninstall The Application
-------------------------

### Remove Application bundle

Just drag&drop the application bundle to trash box.

### Uninstall Privileged Helper Tool
This application contains priviledge helper tool. To uninstall the tool, you need to run xtcpshow-uninstall.sh. Don't forget use sudo to get root priviledge.

    % sudo xtcpshow-uninstall.sh

The script does:

1. unload the helper service from launchd
2. delete executable binary of the helper (/Library/PrivilegedHelperTools/com.mac.hiroki.suenaga.OpenBPF)
3. delete info.plist of the helper (/Library/LaunchDaemons/com.mac.hiroki.suenaga.OpenBPF.plist)

License
-------

Copyright (c) 2013

SUENAGA Hiroki ¥<hiroki_suenaga@mac.com¥>. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
