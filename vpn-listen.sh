#!/bin/bash

DIR="/home/me/.vpn"

if [[ -f "$DIR/.statusmessage" ]]; then
	msg=$(cat "$DIR/.statusmessage")
	echo "$msg"
else
	echo '{"text": "Down VPN", "tooltip":"ip: Down\ncity: Unknown","class":["disconnected"],"alt":"disconnected"}'
fi

handle_sighup() {
	echo $(cat "$DIR/.statusmessage")
}

trap 'handle_sighup' SIGHUP

while true; do
	sleep 1
done
