#!/bin/bash
#
# Script that attempts to read 'autoWIFI.txt' from USB and parse
# that info and directly connect to the corresponding network
# (Deletes original .txt on success) _JMac

###########################################################
# Isolated Fns for this script (called elsewhere in here)
###########################################################
# Log + Exit Fn
#
# Syntax: loggedExit [Log String] [USB Mountpath]
loggedExit() {
    logfile="/usr/local/sbin/autoWIFI.log"
    echo -e "$1" >> $logfile

    # If USB exists, copy log to USB
    if [[ -d "$2" ]]; then
        cp $logfile $2

        # Unmount when done
        sudo umount /mnt/auto/*
        sudo rm -rf /mnt/auto/*
    fi

    exit
}

###########################
# Single ping of google.com
#
# Syntax: pingConnection

pingConnection() {
    if ping -c 1 google.com &> /dev/null; then
        return 0  # Connected to the internet
    else
        return 1  # Not connected to the internet
    fi  
}

###########################################################
#
# Create Log, and lock to prevent concurrent script calls
###########################################################

# Create new logfile if existing log is older than 2 minutes...
logfile="/usr/local/sbin/autoWIFI.log"
if [[ ! -f $logfile || $(find $logfile -type f -mmin +2) ]]; then
    > $logfile
    chmod 666 $logfile
fi

DEVNAME=$1
lockfile="/var/lock/my_udev_lock"

# Immediate exit if this is not an 'sd' device (can't be USB storage)
if [[ "$DEVNAME" != /dev/sd* ]]; then
    exit
fi
sleep 0.1

# Attempt to acquire lock to prevent multiple instances
exec 200>"$lockfile"
if ! flock -n 200; then
    exit 1
fi
sleep 0.5

echo -e "The device triggering the event is: $DEVNAME \n\tTimestamp = ($(date))\n" >> $logfile

###########################################################
#
# Now, there will be only one instance that reaches here - mount drive and look for 'autoWIFI.txt'
##################################################################################################
#
# Check if $DEVNAME is set and is a block device
if [ -b "$DEVNAME" ]; then
    # Use lsblk to check if $DEVNAME is a USB device
    if lsblk -no TRAN "$DEVNAME" | grep -iq "usb"; then
        # It's a USB device; now find the first partition
        first_partition=$(lsblk -ln -o NAME "$DEVNAME" | grep "^${DEVNAME##*/}[0-9]" | head -n 1)
        if [ -n "$first_partition" ]; then
            first_partition="/dev/$first_partition"
            mount_point="/mnt/auto/${first_partition##*/}"

            # Create the mount point directory if it does not exist
            mkdir -p "$mount_point"

            # Attempt to mount the first partition
            mount "$first_partition" "$mount_point"

            if [ $? -eq 0 ]; then

                # Successfully mounted, now list contents
                echo "Successfully mounted to: $mount_point" >> $logfile

                ############################################################
                # Check for file, if exists, then load its settings to WLAN
                ############################################################
                file_path="$mount_point/autoWIFI.txt"

                # Check if the file exists -- don't log this, any USB (like for movies/shows) could be inserted 
                if [ ! -f "$file_path" ]; then
                    loggedExit "File $file_path does not exist." $mount_point
                    exit
                fi

                # Read and extract the SSID and password from the file
                ssid=$(awk -F': ' '/^ssid: /{gsub(/[\r\n]+$/, "", $2); gsub(/^ +| +$/, "", $2); print $2}' "$file_path")
                pass=$(awk -F': ' '/^pass: /{gsub(/[\r\n]+$/, "", $2); gsub(/^ +| +$/, "", $2); print $2}' "$file_path")

                # Ensure both SSID and password were found
                if [ -z "$ssid" ] || [ -z "$pass" ]; then
                    echo -e "\n$file_path found, but format was incorrect. (Err: Empty/Invalid SSID/PW)" >> "$logfile"
                    loggedExit "\n |-|    (ssid= $ssid , pass= $pass ) |-|\n" $mount_point
                fi

                echo -e "Successful Parse of WIFI Info -- (ssid=\"$ssid\", pass=\"$pass\")" >> "$logfile"

                # Determine the lowest numbered wlan interface
                wlan_interface=$(ip link | grep -oP 'wlan\d+' | sort | head -n 1)

                # Check if a wlan interface was found
                if [ -z "$wlan_interface" ]; then
                    loggedExit "No wlan interface found. (Err: Failed ip link cmd)" $mount_point
                fi

                # Update the Wi-Fi settings
                nmcli device wifi connect "$ssid" password "$pass" ifname "$wlan_interface" || {
                    echo -e "Failed to Make Wi-Fi Connection. (Err: Failed 'nmcli' command)" >> "$logfile"
                    loggedExit "  {SSID=\"$ssid\" Password=\"$pass\" ifname=\"$wlan_interface\"}" $mount_point
                }
                echo -e "Wi-Fi settings updated successfully. Connecting to: \"$ssid\"...\n" >> $logfile

                # Verify if it has connected to the internet -- CANT GET TO WORK FROM UDEV EVENT, GIVING UP
                maxAttempts=30
                while true; do
                    if pingConnection; then
                        break
                    fi
                
                    sleep 1
                    echo -e "\tInternet [NOT CONNECTED] -- Remaining Attempts: $maxAttempts..." >> $logfile
                    echo -e "\t\tDebug: $(bash /usr/local/sbin/singlePing.sh)" >> $logfile
                
                    # We tried for 30s, give up.
                    if [ $maxAttempts -eq 0 ]; then
                        loggedExit "Failed to connect to the internet with valid credentials... (Err: 30s timeout)" $mount_point
                    fi

                    ((maxAttempts--))
                done
                sleep 0.5

                echo -e "Successfully connected to: $ssid!" >> $logfile

                # As long as we are sure it is connected - delete the file
                sudo rm $file_path

                # Add a copy of Log back to USB
                cp $logfile $mount_point

                # Unmount when done
                sudo umount /mnt/auto/*
                sudo rm -rf /mnt/auto/*
            else
                echo -e "\n\t(Did not execute: Failed to mount $first_partition)" >> $logfile
            fi
        else
            echo -e "\n\t(Did not execute: No partitions found on $DEVNAME)" >> $logfile
        fi
    else
        echo -e "\n\t(Did not execute: $DEVNAME is not a USB device)" >> $logfile
    fi
else
    echo -e "\n\t(Did not execute: Invalid block device: $DEVNAME)" >> $logfile
fi
##################################################################################################