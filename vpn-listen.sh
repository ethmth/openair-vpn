#!/bin/bash

DIR="/home/me/.vpn"

if [[ -f "$DIR/.statusmessage" ]]; then
	msg=$(cat "$DIR/.statusmessage")
	echo "$msg"
else
	message="{\
\"ip\":\"Unknown\",\
\"vpnip\":\"Unknown\",\
\"homeip\":\"Unknown\",\
\"localip\":\"Unknown\",\
\"file\":\"Unknown\",\
\"type\":\"Unknown\",\
\"city\":\"Unknown\",\
\"text\":\"Status Error VPN\",\
\"messages\": [{\"label\": {\"text\":\"VPN Status Read Error\",\"color\":\"#ff0000\"},\"progress\":{\"value\":0}}],\
\"tooltip\":\"ip: Unknown\ncity: Unknown\nkillswitch: Unknown\",\
\"class\":[\"Unknown\"],\
\"alt\":\"Unknown\"\
}"
	echo "$message"
fi

handle_sighup() {
	echo $(cat "$DIR/.statusmessage")
}

trap 'handle_sighup' SIGHUP

while true; do
	sleep 1
done
