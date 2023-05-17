#!/bin/bash

DIR="/home/me/.vpn"

handle_sighup() {
	echo "SIGHUP signal received"
}

trap 'handle_sighup' SIGHUP

while true; do
	sleep 1
done
