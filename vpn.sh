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

function _extractIPs() {
	cat $DIR/*.ovpn | grep remote | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' > $DIR/.vpnips
	if ! [[ $EUID -ne 0 ]]; then
		chmod 666 $DIR/.vpnips
	fi
}

function _killswitchOff() {

	all_vpn_ips=""	
	if [[ -f "$DIR/.killswitch_ips" ]]; then
		all_vpn_ips=$(cat "$DIR/.killswitch_ips")
	fi
	if [ "$all_vpn_ips" == "" ]; then
		echo "Can't find killswitch_ips. Not changing iptables"
	else
		iptables -P OUTPUT ACCEPT
		iptables -D OUTPUT -o tun+ -j ACCEPT
		iptables -D INPUT -i lo -j ACCEPT
		iptables -D OUTPUT -o lo -j ACCEPT
		iptables -D OUTPUT -d 255.255.255.255 -j ACCEPT
		iptables -D INPUT -s 255.255.255.255 -j ACCEPT
		iptables -D OUTPUT -o $INTERFACE -p udp -m multiport --dports 53,1300:1302,1194:1197 -d $all_vpn_ips -j ACCEPT
		iptables -D OUTPUT -o $INTERFACE -p tcp -m multiport --dports 53,443 -d $all_vpn_ips -j ACCEPT
		
		ip6tables -P OUTPUT ACCEPT
		ip6tables -D INPUT -i lo -j ACCEPT
		ip6tables -D OUTPUT -o lo -j ACCEPT
		ip6tables -D OUTPUT -o tun+ -j ACCEPT
	fi
	
}	

function _killswitchOn() {
	_extractIPs
	all_vpn_ips=""
	while IFS= read -r line; do
		if ! [ "$all_vpn_ips" == "" ]; then
			all_vpn_ips+=","
		fi 
		all_vpn_ips+="$line/24"
	done < "$DIR/.vpnips"

	if [ "$all_vpn_ips" == "" ]; then
		echo "No vpn ips found"
		exit 1
	fi

	iptables -P OUTPUT DROP
	iptables -A OUTPUT -o tun+ -j ACCEPT
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A OUTPUT -o lo -j ACCEPT
	iptables -A OUTPUT -d 255.255.255.255 -j ACCEPT
	iptables -A INPUT -s 255.255.255.255 -j ACCEPT
	iptables -A OUTPUT -o $INTERFACE -p udp -m multiport --dports 53,1300:1302,1194:1197 -d $all_vpn_ips -j ACCEPT
	iptables -A OUTPUT -o $INTERFACE -p tcp -m multiport --dports 53,443 -d $all_vpn_ips -j ACCEPT
	
	ip6tables -P OUTPUT DROP
	ip6tables -A INPUT -i lo -j ACCEPT
	ip6tables -A OUTPUT -o lo -j ACCEPT
	ip6tables -A OUTPUT -o tun+ -j ACCEPT
	
	echo "$all_vpn_ips" > $DIR/.killswitch_ips
	if ! [[ $EUID -ne 0 ]]; then
		chmod 666 $DIR/.killswitch_ips
	fi
}


function _postip() {
	
	LOCAL_IP=$1
	VPN_IP=$2
		
	#echo "Running curl --connect-timeout 5 -o /dev/null -X POST -H \"Content-Type: application/json\" -d \"{\"message\": \"${IFTTT_MESSAGE}\",\"local-ip\": \"${LOCAL_IP}\",\"vpn-ip\": \"${VPN_IP}\"}\" https://maker.ifttt.com/trigger/${IFTTT_EVENT}/json/with/key/${IFTTT_KEY}"
	curl --connect-timeout 5 -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"message\": \"${IFTTT_MESSAGE}\",\"local-ip\": \"${LOCAL_IP}\",\"vpn-ip\": \"${VPN_IP}\"}" https://maker.ifttt.com/trigger/${IFTTT_EVENT}/json/with/key/${IFTTT_KEY} 2>/dev/null
	curl --connect-timeout 5 -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"id\": \"$(cat /etc/hostname)\",\"local\": \"${LOCAL_IP}\",\"ip\": \"${VPN_IP}\"}" $REST_DNS_URL/ip 2>/dev/null
}

function _postLocalDNS() {
	dns_local_ip=$(cat "$DIR/.last_localip")

	# TODO - Update Local DNS if Needed
}

function _postVPNDNS() {
	dns_ip=$(cat "$DIR/.last_vpnip")

	# TODO - Update VPN DNS if Needed
}

function _tablesRemoveLAN() {
	local_inet=$(ip a | grep ${INTERFACE} | grep inet | xargs)
	local_inet=($local_inet)
	local_ip=${local_inet[1]}
	local_extension="${local_ip##*/}"
	local_ip=${local_ip%/*}
	local_subnet="${local_ip%.*}"
	local_subnet="${local_subnet}.0/$local_extension"
	
	# TODO: Make this work with non /24 subnets

	iptables -D OUTPUT -d $local_subnet -p udp --dport 53 -j DROP 2>/dev/null
	iptables -D OUTPUT -d $local_subnet -p tcp --dport 53 -j DROP 2>/dev/null
	iptables -D INPUT -s $local_subnet -p udp --dport 53 -j DROP 2>/dev/null
	iptables -D INPUT -s $local_subnet -p tcp --dport 53 -j DROP 2>/dev/null
	iptables -D OUTPUT -d $local_subnet -j ACCEPT 2>/dev/null
	iptables -D INPUT -s $local_subnet -j ACCEPT 2>/dev/null
}

function _tablesAddLAN() {
	local_inet=$(ip a | grep ${INTERFACE} | grep inet | xargs)
	local_inet=($local_inet)
	local_ip=${local_inet[1]}
	local_extension="${local_ip##*/}"
	local_ip=${local_ip%/*}
	local_subnet="${local_ip%.*}"
	local_subnet="${local_subnet}.0/$local_extension"

	# TODO: Make this work with non /24 subnets

	iptables -A OUTPUT -d $local_subnet -p udp --dport 53 -j DROP
	iptables -A OUTPUT -d $local_subnet -p tcp --dport 53 -j DROP
	iptables -A INPUT -s $local_subnet -p udp --dport 53 -j DROP
	iptables -A INPUT -s $local_subnet -p tcp --dport 53 -j DROP
	iptables -A OUTPUT -d $local_subnet -j ACCEPT
	iptables -A INPUT -s $local_subnet -j ACCEPT
}

function _updateeverything() {
	_updateip
	_updatestatus
}

function _updateip() {
	
	ipinfo=$(curl --connect-timeout 5 https://ipleak.net/json/ 2>/dev/null | jq -r '.ip, .type, .city_name')
	curl_exit_status=$?
	if [ $curl_exit_status -eq 0 ]; then
		while IFS= read -r line; do
    		if [ -z "$ip" ]; then
        		ip="$line"
    		elif [ -z "$typ" ]; then
        		typ="$line"
    		elif [ -z "$city" ]; then
        		city="$line"
    		fi
		done <<< "$ipinfo"
	fi
	ip_old=""
	typ_old=""
	city_old=""
	if [[ -e "$DIR/.ipinfo" ]]; then
		ipinfo_old=$(cat "$DIR/.ipinfo")
		while IFS= read -r line; do
    		if [ -z "$ip_old" ]; then
        		ip_old="$line"
    		elif [ -z "$typ_old" ]; then
        		typ_old="$line"
    		elif [ -z "$city_old" ]; then
        		city_old="$line"
    		fi
		done <<< "$ipinfo_old"
	fi

	printf "$ipinfo" > $DIR/.ipinfo
	if ! [[ $EUID -ne 0 ]]; then
		chmod 666 $DIR/.ipinfo	
	fi

	if ! [ "$ip" == "$ip_old" ]; then
		airvpn_connected=$(echo "$typ" | grep -i "AirVPN" | wc -l)
	
		local_inet=$(ip a | grep ${INTERFACE} | grep inet | xargs)
		local_inet=($local_inet)
		local_ip=${local_inet[1]}
		local_ip=${local_ip%/*}
	
		if [ "$airvpn_connected" -eq 0 ]; then
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
				_postVPNDNS
			fi
		fi


		old_local_ip=""
		if [[ -e "$DIR/.last_localip" ]]; then
			old_local_ip=$(cat "$DIR/.last_localip")
		fi
		if ! [ "$old_local_ip" == "$local_ip" ]; then
			echo "$local_ip" > $DIR/.last_localip
			if ! [[ $EUID -ne 0 ]]; then
				chmod 666 $DIR/.last_localip
			fi
			_postLocalDNS
		fi
		
		_postip "${local_ip}" "${ip}"
	fi

	
}

function _updatestatus() {

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
	
	local_inet=$(ip a | grep ${INTERFACE} | grep inet | xargs)
	local_inet=($local_inet)
	local_ip=${local_inet[1]}
	local_ip=${local_ip%/*}

	class="connected"
	color="#ffffff"
	home_ip=""
	if [ "$airvpn_connected" -eq 0 ]; then
		connection_file="none"
		vpn_ip=""
		class="disconnected"
		color="#ff0000"
		home_ip="$ip"
		ip=""
	fi

	ks_status=""	
	if [[ -f "$DIR/.killswitch_status" ]]; then
		ks_status=$(cat "$DIR/.killswitch_status")
	fi
	
	lan_status=""	
	if [[ -f "$DIR/.lan_status" ]]; then
		lan_status=$(cat "$DIR/.lan_status")
	fi
		
	text="${ip}${home_ip}"
	if [ "$text" == "" ]; then
		text="Unreachable"
		city="Unknown"
	fi

	pipe_message="{\
\"ip\":\"${ip}\",\
\"vpnip\":\"${vpn_ip}\",\
\"homeip\":\"${home_ip}\",\
\"localip\":\"${local_ip}\",\
\"file\":\"${connection_file}\",\
\"type\":\"${typ}\",\
\"city\":\"${city}\",\
\"text\":\"KS $ks_status LAN $lan_status $text VPN\",\
\"messages\": [{\"label\": {\"text\":\"VPN ${class} - KS $ks_status - LAN $lan_status - $text\",\"color\":\"${color}\"},\"progress\":{\"value\":0}}],\
\"tooltip\":\"ip: $text\ncity: ${city}\nkillswitch: ${ks_status}\",\
\"class\":[\"${class}\"],\
\"alt\":\"${class}\"\
}"

	old_pipe_message=""
	if [[ -f "$DIR/.statusmessage" ]]; then
		old_pipe_message=$(cat "$DIR/.statusmessage")
	fi

	if ! [ "$pipe_message" == "$old_pipe_message" ]; then
		echo "$pipe_message" > $DIR/.statusmessage
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR/.statusmessage
		fi
		killall -1 vpn-listen 2>/dev/null
	fi

	echo "Public IP: ${ip}${home_ip}, VPN IP: ${vpn_ip}, City: ${city}, Type: ${typ}"
}

function check() {
	curl --connect-timeout 5 https://ipleak.net/json/ 2>/dev/null | jq -r '.ip, .type, .city_name'
}

function connect() {

	_checkroot

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	if ! [ $openvpn_on -eq 0 ]; then
		killall openvpn
		sleep 1
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

	sleep 4
	_updateeverything
}

function disconnect() {
	_checkroot

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	if ! [ $openvpn_on -eq 0 ]; then
		killall openvpn
		sleep 4
		_updateeverything
	fi

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	if [ $openvpn_on -eq 0 ]; then
		echo "Openvpn disconnected"
	fi
}


function killswitch() {
	
	_checkroot
	
	if [ "$1" == "on" ]; then
		ks_status=""	
		if [[ -f "$DIR/.killswitch_status" ]]; then
			ks_status=$(cat "$DIR/.killswitch_status")
		fi
		if [ "$ks_status" == "on" ]; then
			_killswitchOff
		fi

		_killswitchOn

		lan_status=""	
		if [[ -f "$DIR/.lan_status" ]]; then
			lan_status=$(cat "$DIR/.lan_status")
		fi
		if [ "$lan_status" == "on" ]; then
			_tablesAddLAN
		fi
		
		echo "on" > $DIR/.killswitch_status
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR/.killswitch_status
		fi
	elif [ "$1" == "off" ]; then
		ks_status=""	
		if [[ -f "$DIR/.killswitch_status" ]]; then
			ks_status=$(cat "$DIR/.killswitch_status")
		fi
		if [ "$ks_status" == "off" ]; then
			echo "Killswitch already off"
			exit 0
		fi

		_tablesRemoveLAN
		
		_killswitchOff

		echo "off" > $DIR/.killswitch_status
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR/.killswitch_status
		fi
	else
		echo "Usage: vpn killswitch <on|off>"
		exit 1
	fi	
	
	sleep 1		
	_updateeverything
}

function lan() {

	_checkroot
	
	if [ "$1" == "on" ]; then
		lan_status=""	
		if [[ -f "$DIR/.lan_status" ]]; then
			lan_status=$(cat "$DIR/.lan_status")
		fi
		if [ "$lan_status" == "on" ]; then
			echo "LAN Already On"
			exit 1
		fi
		ks_status=""	
		if [[ -f "$DIR/.killswitch_status" ]]; then
			ks_status=$(cat "$DIR/.killswitch_status")
		fi
		if [ "$ks_status" == "on" ]; then
			_tablesAddLAN
		else
			echo "Killswitch not on, so not applying rules, but settings LAN to on for future"
		fi

		echo "on" > $DIR/.lan_status
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR/.lan_status
		fi
	elif [ "$1" == "off" ]; then
		lan_status=""	
		if [[ -f "$DIR/.lan_status" ]]; then
			lan_status=$(cat "$DIR/.lan_status")
		fi
		if [ "$lan_status" == "off" ]; then
			echo "LAN Already Off"
			exit 1
		fi
		_tablesRemoveLAN
		
		echo "off" > $DIR/.lan_status
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR/.lan_status
		fi
	else
		echo "Usage: vpn lan <on|off>"
		exit 1
	fi
	_updatestatus
}

function reset() {
	rm $DIR/.vpnips
	rm $DIR/.statusmessage
	rm $DIR/.ipinfo
	rm $DIR/.killswitch_status
	rm $DIR/.lan_status
}

function update() {
	_updateeverything	
}

function init() {
	reset
	killswitch on
	connect
	lan off
}

if [ "$1" == "check" ]; then
	check ${@:2:$#-1}
elif ([ "$1" == "connect" ] || [ "$1" == "on" ]); then
	connect ${@:2:$#-1}
elif ([ "$1" == "disconnect" ] || [ "$1" == "off" ]); then
	disconnect ${@:2:$#-1}
elif ([ "$1" == "killswitch" ] || [ "$1" == "ks" ]); then
	killswitch ${@:2:$#-1}
elif [ "$1" == "lan" ]; then
	lan ${@:2:$#-1}
elif [ "$1" == "reset" ]; then
	reset ${@:2:$#-1}
elif [ "$1" == "update" ]; then
	update ${@:2:$#-1}
elif [ "$1" == "init" ]; then
	init ${@:2:$#-1}
else 
	printf "Options \n"
	printf	"\t check\n"
	printf	"\t connect <new|default>\n"
	printf	"\t disconnect\n"
	printf	"\t killswitch <on|off>\n"
	printf	"\t lan\n"
	printf	"\t reset\n"
	printf	"\t update\n"
	printf	"\t init\n"
	exit 0
fi
