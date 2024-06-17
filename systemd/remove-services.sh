#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "This script should be run with root/sudo privileges."
	exit 1
fi

CUR_USER=$(whoami)

systemctl disable vpn-init.service
systemctl disable vpn-update.timer

if [ -f "/etc/systemd/system/vpn-init.service" ]; then
	rm /etc/systemd/system/vpn-init.service
fi

if [ -f "/etc/systemd/system/vpn-update.service" ]; then
	rm /etc/systemd/system/vpn-update.service
fi

if [ -f "/etc/systemd/system/vpn-update.timer" ]; then
	rm /etc/systemd/system/vpn-update.timer
fi
