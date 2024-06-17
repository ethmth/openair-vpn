#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "This script should be run with root/sudo privileges."
	exit 1
fi

CUR_USER=$(whoami)

if ! [ -f "vpn-check.service" ]; then
	echo "vpn-check.service doesn't exist."
	exit 1
fi

if ! [ -f "vpn-connect.service" ]; then
	echo "vpn-connect.service doesn't exist."
	exit 1
fi

if ! [ -f "vpn-killswitch.service" ]; then
	echo "vpn-killswitch.service doesn't exist."
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

cp vpn-check.service /etc/systemd/system/vpn-check.service
cp vpn-connect.service /etc/systemd/system/vpn-connect.service
cp vpn-killswitch.service /etc/systemd/system/vpn-killswitch.service

cp vpn-update.service /etc/systemd/system/vpn-update.service
cp vpn-update.timer /etc/systemd/system/vpn-update.timer

systemctl enable vpn-check.service
systemctl enable vpn-connect.service
systemctl enable vpn-killswitch.service

systemctl enable vpn-update.timer

