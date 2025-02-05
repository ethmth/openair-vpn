#!/bin/bash

DIR="/home/me/.vpn"


# message_sent=0

# if [[ -f "$DIR/.isHidden" ]]; then
# 	msg=$(cat "$DIR/.isHidden")
# 	if [[ "$msg" == *"true"* ]]; then
# 		message="{\
# \"ip\":\"Unknown\",\
# \"vpnip\":\"Unknown\",\
# \"homeip\":\"Unknown\",\
# \"localip\":\"Unknown\",\
# \"file\":\"Unknown\",\
# \"type\":\"Unknown\",\
# \"city\":\"Unknown\",\
# \"text\":\"\",\
# \"messages\": [{\"label\": {\"text\":\"\",\"color\":\"\"},\"progress\":{\"value\":0}}],\
# \"tooltip\":\"\",\
# \"class\":[\"Unknown\"],\
# \"alt\":\"Unknown\"\
# }"
# 		echo "$message"
# 		message_sent=1
# 	fi
# fi

# if ! ((message_sent)); then
# 	if [[ -f "$DIR/.statusmessage" ]]; then
# 		msg=$(cat "$DIR/.statusmessage")
# 		echo "$msg"
# 		message_sent=1
# 	else
# 		message="{\
# \"ip\":\"Unknown\",\
# \"vpnip\":\"Unknown\",\
# \"homeip\":\"Unknown\",\
# \"localip\":\"Unknown\",\
# \"file\":\"Unknown\",\
# \"type\":\"Unknown\",\
# \"city\":\"Unknown\",\
# \"text\":\"Status Error VPN\",\
# \"messages\": [{\"label\": {\"text\":\"VPN Status Read Error\",\"color\":\"#ff0000\"},\"progress\":{\"value\":0}}],\
# \"tooltip\":\"ip: Unknown\ncity: Unknown\nkillswitch: Unknown\",\
# \"class\":[\"Unknown\"],\
# \"alt\":\"Unknown\"\
# }"
# 		echo "$message"
# 		message_sent=1
# 	fi
# fi

handle_sighup() {
	# echo $(cat "$DIR/.statusmessage")
	message_sent=0
	echo "Before 1st if"
	if [[ -f "$DIR/.isHidden" ]]; then
		echo "In 1st if"
		msg=$(cat "$DIR/.isHidden")
		if [[ "$msg" == *"true"* ]]; then
			message="{\
\"ip\":\"Unknown\",\
\"vpnip\":\"Unknown\",\
\"homeip\":\"Unknown\",\
\"localip\":\"Unknown\",\
\"file\":\"Unknown\",\
\"type\":\"Unknown\",\
\"city\":\"Unknown\",\
\"text\":\"\",\
\"messages\": [{\"label\": {\"text\":\"\",\"color\":\"\"},\"progress\":{\"value\":0}}],\
\"tooltip\":\"\",\
\"class\":[\"Unknown\"],\
\"alt\":\"Unknown\"\
}"
			echo "$message"
			message_sent=1
		fi
	fi

	echo "Before 2nd if"

	if ! ((message_sent)); then
		echo "In 2nd if"
		if [[ -f "$DIR/.statusmessage" ]]; then
			msg=$(cat "$DIR/.statusmessage")
			echo "$msg"
			message_sent=1
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
			message_sent=1
		fi
	fi
}

handle_sighup

trap 'handle_sighup' SIGHUP

while true; do
	sleep 1
done
