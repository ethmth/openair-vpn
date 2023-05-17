#!/bin/bash

DIR="/home/me/.vpn"
DEFAULT_FILE="AirVPN_SG-Singapore_Lacaille_TCP-443-Entry3.ovpn"
INTERFACE="eth0"
IFTTT_KEY=""
IFTTT_EVENT="pc_awoken"
IFTTT_MESSAGE="My pc got a new ip!"
REST_DNS_URL="http://127.0.0.1:24601"

function _checkroot() {
	if [[ $EUID -ne 0 ]]; then
		echo "This script must be run with root/sudo privileges."
		exit 1
	fi
}

function _postip() {
	
	LOCAL_IP=$1
	VPN_IP=$2
		
	echo "Running curl -o /dev/null -X POST -H \"Content-Type: application/json\" -d \"{\"message\": \"${IFTTT_MESSAGE}\",\"local-ip\": \"${LOCAL_IP}\",\"vpn-ip\": \"${VPN_IP}\"}\" https://maker.ifttt.com/trigger/${IFTTT_EVENT}/json/with/key/${IFTTT_KEY}"
	curl -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"message\": \"${IFTTT_MESSAGE}\",\"local-ip\": \"${LOCAL_IP}\",\"vpn-ip\": \"${VPN_IP}\"}" https://maker.ifttt.com/trigger/${IFTTT_EVENT}/json/with/key/${IFTTT_KEY} 2>/dev/null
	curl -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"id\": \"$(cat /etc/hostname)\",\"local\": \"${LOCAL_IP}\",\"ip\": \"${VPN_IP}\"}" $REST_DNS_URL/ip 2>/dev/null
}

function _statusupdate() {

	ipinfo=$(cat "$DIR/.ipinfo")
	while IFS= read -r line; do
    	if [ -z "$ip" ]; then
        	ip="$line"
    	elif [ -z "$typ" ]; then
        	typ="$line"
    	elif [ -z "$city" ]; then
        	city="$line"
    	fi
	done <<< "$ipinfo"

	connection_file=$(cat "$DIR/.last_serverfile")
	vpn_ip=$(cat "$DIR/$connection_file" | grep remote | head -n 1 | awk '{print $2}')

	airvpn_connected=$(echo "$typ" | grep -i "AirVPN" | wc -l)

	class="connected"
	home_ip=""
	if [ "$airvpn_connected" -eq 0 ]; then
		connection_file="none"
		vpn_ip=""
		class="disconnected"
		home_ip="$ip"
		ip=""
	else
		old_ip=""
		if [[ -e "$DIR/.last_vpnip" ]]; then
			old_ip=$(cat "$DIR/.last_vpnip")
		fi
		if ! [ "$ip" == "$old_ip" ]; then
			echo "$ip" > $DIR/.last_vpnip
			if ! [[ $EUID -ne 0 ]]; then
				chmod 666 $DIR/.last_vpnip
			fi
			_updateVPNDNS
		fi
	fi

	local_inet=$(ip a | grep ${INTERFACE} | grep inet | xargs)
	local_inet=($local_inet)
	local_ip=${local_inet[1]}
	local_ip=${local_ip%/*}

	old_local_ip=""
	if [[ -e "$DIR/.last_localip" ]]; then
		old_local_ip=$(cat "$DIR/.last_localip")
	fi
	if ! [ "$old_local_ip" == "$local_ip" ]; then
		echo "$local_ip" > $DIR/.last_localip
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR/.last_localip
		fi
		_updateLocalDNS
	fi
	

	pipe_message="{\
\"ip\":\"${ip}\",\
\"vpnip\":\"${vpn_ip}\",\
\"homeip\":\"${home_ip}\",\
\"localip\":\"${local_ip}\",\
\"file\":\"${connection_file}\",\
\"type\":\"${typ}\",\
\"city\":\"${city}\",\
\"text\":\"${ip}${home_ip} VPN\",\
\"tooltip\":\"ip: ${ip}${home_ip}\ncity: ${city}\",\
\"class\":[\"${class}\"],\
\"alt\":\"${class}\"\
}"

	echo "$pipe_message" > $DIR/.statusmessage
	if ! [[ $EUID -ne 0 ]]; then
		chmod 666 $DIR/.statusmessage
	fi
	killall -1 vpn-listen

	echo "Public IP: ${ip}${home_ip}, VPN IP: ${vpn_ip}, City: ${city}, Type: ${typ}"
	_postip "${local_ip}" "${ip}"
}

function _updateipinfo() {
	ipinfo=$(curl https://ipleak.net/json/ 2>/dev/null | jq -r '.ip, .type, .city_name')
	curl_exit_status=$?
	if [ $curl_exit_status -eq 0 ]; then
		oldinfo=""
		if [[ -e "$DIR/.ipinfo" ]]; then
			oldinfo=$(cat "$DIR/.ipinfo")
		fi
		if ! [ "$ipinfo" == "$oldinfo" ]; then
			printf "$ipinfo" > $DIR/.ipinfo
			if ! [[ $EUID -ne 0 ]]; then
				chmod 666 $DIR/.ipinfo	
			fi
			_statusupdate
		fi
	fi
}

function _updateVPNDNS() {
	dns_ip=$(cat "$DIR/.last_vpnip")

	# TODO - Update VPN DNS if Needed
}

function _updateLocalDNS() {
	dns_local_ip=$(cat "$DIR/.last_localip")

	# TODO - Update Local DNS if Needed
}


function check() {
	curl https://ipleak.net/json/ 2>/dev/null | jq -r '.ip, .type, .city_name'
}

function connect() {

	_checkroot

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	if ! [ $openvpn_on -eq 0 ]; then
		killall openvpn
	fi

	if [ ! -d "$DIR" ]; then
		mkdir -p "$DIR"
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR
		fi
	fi

	count=$(ls -a1 $DIR | grep ovpn | wc -l)
	zip_count=$(unzip -l "$DIR/AirVPN.zip" | grep -oE '[0-9]+ files' | grep -oE '[0-9]+')
	md5_hash=$(cat "$DIR/AirVPN.md5")

	if [ -e "$DIR/AirVPN.zip" ]; then
		md5_cur=$(md5sum "$DIR/AirVPN.zip" | cut -d' ' -f1)
		if ! ([ "$count" -eq "$zip_count" ] && [ "$md5_cur" = "$md5_hash" ]); then
			rm $DIR/*.ovpn
			unzip $DIR/AirVPN.zip -d $DIR
			echo "$md5_cur" > $DIR/AirVPN.md5
		fi
		count=$(ls -a1 $DIR | grep ovpn | wc -l)
	fi

	if [ "$count" -eq 0 ]; then
		echo "No .ovpn files found."
		exit 1
	fi

	server_file=""
	if [[ "$1" = "new" ]]; then
		server_file=$(ls -1 $DIR | grep ovpn | fzf)
	else
		server_file=""
		if [[ -f "$DIR/.last_serverfile" ]]; then
			server_file=$(cat "$DIR/.last_serverfile")
		fi
		if ([[ "$server_file" = "" ]] || [[ "$1" = "default" ]]); then
			server_file=$DEFAULT_FILE
		fi
	fi

	if ! [[ -f "$DIR/$server_file" ]]; then
		echo "Server config file $DIR/$server_file doesn't exist"
		echo "Run vpn connect new to set a new server"
		exit 1
	fi

	echo "Connecting to $server_file..."
	openvpn --script-security 2 --up /etc/openvpn/update-resolv-conf --down /etc/openvpn/update-resolv-conf --down-pre --config $DIR/$server_file --daemon

	old_file=$(cat "$DIR/.last_serverfile")
	if ! [[ "$old_file" = "$server_file" ]]; then
		echo "$server_file" > $DIR/.last_serverfile
		chmod 666 $DIR/.last_serverfile
	fi

	if [[ "$1" = "startup" ]]; then
		sleep 15
	else
		sleep 5
	fi
	_updateipinfo
}

function disconnect() {
	_checkroot

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	if ! [ $openvpn_on -eq 0 ]; then
		killall openvpn
		sleep 5
		_updateipinfo
	fi

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	if [ $openvpn_on -eq 0 ]; then
		echo "Openvpn disconnected"
	fi
}

function reset() {
	rm $DIR/.statusmessage
	rm $DIR/.ipinfo
}

function update() {
	_updateipinfo	
}

if [ "$1" == "check" ]; then
	check ${@:2:$#-1}
elif [ "$1" == "connect" ]; then
	connect ${@:2:$#-1}
elif [ "$1" == "disconnect" ]; then
	disconnect ${@:2:$#-1}
elif [ "$1" == "reset" ]; then
	reset ${@:2:$#-1}
elif [ "$1" == "update" ]; then
	update ${@:2:$#-1}
else 
	printf "Options \n"
	printf	"\t check\n"
	printf	"\t connect <new|default>\n"
	printf	"\t disconnect\n"
	printf	"\t reset\n"
	printf	"\t update\n"
	exit 0
fi
