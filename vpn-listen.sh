#!/bin/bash

DIR="/home/me/.vpn"

handle_sighup() {
	echo $(cat "$DIR/.statusmessage")
}

trap 'handle_sighup' SIGHUP

while true; do
	sleep 1
done
