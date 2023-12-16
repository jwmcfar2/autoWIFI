# autoWIFI

Simple scripts/code for Linux system to allow a specifically formatted '.txt' file on any inserted USB to be parsed and used to config the first detected wlan device - allowing for instant setup of wlan without needing to log into device.

# Setup

You can simply just run my script in the root of this repo (sudo may be needed): **./setup.sh**

OR

Setup is simple and can be done manually - there are only 3 single files needed:
  - The service file (`autoWIFIHelper@.service`), which allows for root commands (such as moving files and deleting wifi text file if this is successful) needs to be added to directory: **/etc/systemd/system/**
  - The udev rules file (`99-usb.rules`), which triggers an event every time a block device is detected for the first time (such as USB storage), which needs to go in directory: **/etc/udev/rules.d/**
  - The script itself (`autoWIFI.sh`), which is 99% of the functionality - you can put this anywhere, but you need to make sure it matches the directory listed in `autoWIFIHelper@.service` -- By default I put this in **/usr/local/sbin/**

Then, be sure to restart udev / system services:

>sudo udevadm control --reload-rules
>
>sudo udevadm trigger
>
>sudo systemctl daemon-reload

# Use

Simply plugging in a USB that contains a *specifically formatted* (read further below) file called "autoWIFI.txt", will allow this script to parse it for the ssid and password provided and connect the first discovered wlan device to it (checks for any wifi cards, picks the first one, give it the info on this text file).

The script will then double check that it is connected to the internet, and if so, delete the "autoWIFI.txt" file automatically (for sensitivity reasons).

As long as the USB is successfully mounted during the execution of the code, _**a '.log' file will be copied back to the USB for more information**_ - such as reported errors or confirmed success. Otherwise, this log file will always be accessible on the device at **/usr/local/sbin**.

# USB Text File (autoWIFI.txt) format

Make sure, in regards to the format of the text file on the USB, that:
  - You have named the file *exactly* "autoWIFI.txt"
  - The format of its contents matches this exactly (only 2 lines, no leading spaces, space after first tokens '**ssid:**' & '**pass:**'):
  >ssid: [WIFI Name]
  >
  >pass: [Password]

I have included an example "autoWIFI.txt" in **example/**

# Uninstall

I have added a simple uninstall script **uninstall.sh**, which will simply delete the files that I added via setup.sh (will prompt and warn you before it does, with exactly the commands it will run)

OR

If you have installed these files manually - best practice would be to delete them manually as well.

Once removed, either restart the system or run the commands to restart udev / system services:

>sudo udevadm control --reload-rules
>
>sudo udevadm trigger
>
>sudo systemctl daemon-reload