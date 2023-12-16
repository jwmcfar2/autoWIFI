#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo -e "This script must be run as super-user/root (run 'sudo $(basename "$0")')"
  exit 1
fi

echo -e "\nMoving files from src/ and changing permissions...\n(This script should be ran as root)\n"

sudo cp src/autoWIFI.sh /usr/local/sbin/
sudo cp src/autoWIFIHelper@.service /etc/systemd/system/
sudo cp src/99-usb.rules /etc/udev/rules.d/

sudo chmod 777 /usr/local/sbin/autoWIFI.sh
sudo chmod 777 /etc/systemd/system/autoWIFIHelper@.service
sudo chmod 777 /etc/udev/rules.d/99-usb.rules

sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl daemon-reload

echo -e "\t...Finished Script.\n"