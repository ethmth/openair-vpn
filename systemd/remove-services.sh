#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "This script should be run with root/sudo privileges."
	exit 1
fi

CUR_USER=$(whoami)

systemctl disable vpn-check.service
systemctl disable vpn-connect.service
systemctl disable vpn-killswitch.service

systemctl disable vpn-update.timer

if [ -f "/etc/systemd/system/vpn-check.service" ]; then
	rm /etc/systemd/system/vpn-check.service
fi

if [ -f "/etc/systemd/system/vpn-connect.service" ]; then
	rm /etc/systemd/system/vpn-connect.service
fi

if [ -f "/etc/systemd/system/vpn-killswitch.service" ]; then
	rm /etc/systemd/system/vpn-killswitch.service
fi

if [ -f "/etc/systemd/system/vpn-reset.service" ]; then
	rm /etc/systemd/system/vpn-reset.service
fi

if [ -f "/etc/systemd/system/vpn-update.service" ]; then
	rm /etc/systemd/system/vpn-update.service
fi

if [ -f "/etc/systemd/system/vpn-update.timer" ]; then
	rm /etc/systemd/system/vpn-update.timer
fi
