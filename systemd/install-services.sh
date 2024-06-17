#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "This script should be run with root/sudo privileges."
	exit 1
fi

CUR_USER=$(whoami)

if ! [ -f "vpn-init.service" ]; then
	echo "vpn-init.service doesn't exist."
	exit 1
fi

if ! [ -f "vpn-update.service" ]; then
	echo "vpn-update.service doesn't exist."
	exit 1
fi

if ! [ -f "vpn-update.timer" ]; then
	echo "vpn-update.timer doesn't exist."
	exit 1
fi

cp vpn-init.service /etc/systemd/system/vpn-init.service
cp vpn-update.service /etc/systemd/system/vpn-update.service
cp vpn-update.timer /etc/systemd/system/vpn-update.timer

systemctl enable vpn-init.service
systemctl enable vpn-update.timer

