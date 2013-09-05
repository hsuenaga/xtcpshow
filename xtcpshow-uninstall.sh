#!/bin/sh
PLIST="/Library/LaunchDaemons/com.mac.hiroki.suenaga.OpenBPF.plist"
PROG="/Library/PrivilegedHelperTools/com.mac.hiroki.suenaga.OpenBPF"

echo "Uninstalling xtcpshow Helper tools"

if [ -f $PLIST ]; then
  /bin/launchctl unload $PLIST
fi

rm -f $PLIST
rm -f $PROG
echo "Done"
