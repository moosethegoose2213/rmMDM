#!/bin/bash
[ $UID = 0 ] || exec sudo "$0" "$@"
#[ $UID = 0 ] || exec sudo /"$(echo $0 | cut -c 2- )" "$@"

#uncomment 'set -e' to enable debugging mode
#set -e
sip=$(csrutil status)
if [[ "$sip" == *enabled* ]]; then
	echo "Please disable SIP, then try again."
	exit
fi
OS=$(sw_vers | head -n 2 | tail -n 1 | cut -f2 -d : | cut -c 2-)

if [ ! -e /System/Library/LaunchAgents/com.apple.ManagedClientAgent.agent.plist ]; then
	choice=$(osascript -e 'display alert "Continue?" message "This OS already appears to be patched, are you sure you want to continue?" buttons {"Yes", "No"}')
	if [[ $choice == 'button returned:No' ]]; then
		exit
	fi
fi

if [[ $OS == *"10.15"* ]]; then
	mount -uw /
fi

echo $OS
if [[ "$OS" < 10.16 ]]; then
	echo "Removing files from LaunchAgents"
	cd /System/Library/LaunchAgents

	if [ ! -d rmMDM ]; then
		mkdir rmMDM
	fi
	mv com.apple.ManagedClientAgent.* rmMDM/
	mv com.apple.mdmclient.* rmMDM/

	echo "Removing files from LaunchDaemons"
	cd ../LaunchDaemons
	if [ ! -d rmMDM ]; then
		mkdir rmMDM
	fi
	mv com.apple.ManagedClient.* rmMDM/
	mv com.apple.mdmclient.* rmMDM/
	exit
fi

echo 'Determining mount point of "Macintosh SSD"'
mountpoint=$(df "/" | tail -1 | sed -e 's@ .*@@'| sed 's/..$//')
echo "Macintosh SSD is mounted at $mountpoint"
echo ""

authroot=$(csrutil authenticated-root)
if [[ "$authroot" == *enabled* ]]; then
	echo "Please disable authenticated-root, then try again."
	exit
fi
#if [ ! -d ~/mount ]; then
#echo "Making temporary mountpoint"
#mkdir ~/mount
#fi

echo "Mounting snapshot as rewritable..."
mount -o nobrowse -t apfs $mountpoint /System/Volumes/Update/mnt1

echo "Removing files from LaunchAgents"
cd /System/Volumes/Update/mnt1/System/Library/LaunchAgents

if [ ! -d rmMDM ]; then
	mkdir rmMDM
fi
mv com.apple.ManagedClientAgent.* rmMDM/
mv com.apple.mdmclient.* rmMDM/

echo "Removing files from LaunchDaemons"
cd ../LaunchDaemons
if [ ! -d rmMDM ]; then
	mkdir rmMDM
fi
mv com.apple.ManagedClient.* rmMDM/
mv com.apple.mdmclient.* rmMDM/

echo "Creating new snapshot..."
bless --folder /System/Volumes/Update/mnt1/System/Library/CoreServices --bootefi --create-snapshot

echo "Done. Please reboot for the changes to take effect."
