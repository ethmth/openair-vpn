#!/bin/bash

PROVIDER="AzireVPN"
DIR="/home/me/.vpn"
DEFAULT_FILE="AirVPN_SG-Singapore_Lacaille_TCP-443-Entry3.ovpn"
INTERFACE="eth0"
IFTTT_KEY=""
IFTTT_EVENT="pc_awoken"
IFTTT_MESSAGE="My pc got a new ip!"

LAN_DEFAULT="off"
IFTTT_ON=1
HOST_TO_PING="1.1.1.1"
DNS_SERVER="1.1.1.1"
WG_IFACE="tun0"

INCOMING_PORTS="22,1714:1764"

function has_local_ip() {
  local_ip=$(ip addr show "$INTERFACE" | grep -oP 'inet\s+\K[\d.]+')
  if [[ "$local_ip" =~ ^192\.168\. || "$local_ip" =~ ^10\. || "$local_ip" =~ ^172\.16\. ]]; then
    return 0
  else
    return 1
  fi
}

function check_internet_connectivity() {
  ping -c 1 -W 1 "$HOST_TO_PING" &> /dev/null
  return $?
}

function _checkroot() {
	if [[ $EUID -ne 0 ]]; then
		echo "This script must be run with root/sudo privileges."
		exit 1
	fi
}

function is_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
				echo "0"
                return 0
            fi
        done
		echo "1"
        return 1
    else
		echo "0"
        return 0
    fi
}


function _killswitchOff() {
	# iptables -P INPUT ACCEPT
	# iptables -D INPUT -i tun+ -j ACCEPT
	# iptables -D INPUT -i lo -j ACCEPT
	# iptables -D INPUT -i virbr+ -j ACCEPT
	# iptables -D INPUT -i vnet+ -j ACCEPT
	# iptables -D INPUT -i docker+ -j ACCEPT
	# iptables -D INPUT -i br-+ -j ACCEPT
	# iptables -D INPUT -s 255.255.255.255 -j ACCEPT

	iptables -P OUTPUT ACCEPT
	iptables -D OUTPUT -o tun+ -j ACCEPT
	iptables -D OUTPUT -o lo -j ACCEPT
	iptables -D OUTPUT -o virbr+ -j ACCEPT
	iptables -D OUTPUT -o vnet+ -j ACCEPT
	iptables -D OUTPUT -o docker+ -j ACCEPT
	iptables -D OUTPUT -o br-+ -j ACCEPT
	iptables -D OUTPUT -d 255.255.255.255 -j ACCEPT

	iptables -P FORWARD ACCEPT
	iptables -D FORWARD -i tun+ -o virbr+ -j ACCEPT
	iptables -D FORWARD -i virbr+ -o tun+ -j ACCEPT
	iptables -D FORWARD -i virbr+ -o virbr+ -j ACCEPT
	iptables -D FORWARD -i vnet+ -o vnet+ -j ACCEPT
	iptables -D FORWARD -i virbr+ -o vnet+ -j ACCEPT
	iptables -D FORWARD -i vnet+ -o virbr+ -j ACCEPT

	ip6tables -P INPUT ACCEPT
	ip6tables -D INPUT -i tun+ -j ACCEPT
	ip6tables -D INPUT -i lo -j ACCEPT
	
	ip6tables -P OUTPUT ACCEPT
	ip6tables -D OUTPUT -o tun+ -j ACCEPT
	ip6tables -D OUTPUT -o lo -j ACCEPT

	ip6tables -P FORWARD ACCEPT
}	

function _killswitchOn() {
	# iptables -P INPUT DROP
	# iptables -A INPUT -i tun+ -j ACCEPT
	# iptables -A INPUT -i lo -j ACCEPT
	# iptables -A INPUT -i virbr+ -j ACCEPT
	# iptables -A INPUT -i vnet+ -j ACCEPT
	# iptables -A INPUT -i docker+ -j ACCEPT
	# iptables -A INPUT -i br-+ -j ACCEPT
	# iptables -A INPUT -s 255.255.255.255 -j ACCEPT

	iptables -P OUTPUT DROP
	iptables -A OUTPUT -o tun+ -j ACCEPT
	iptables -A OUTPUT -o lo -j ACCEPT
	iptables -A OUTPUT -o virbr+ -j ACCEPT
	iptables -A OUTPUT -o vnet+ -j ACCEPT
	iptables -A OUTPUT -o docker+ -j ACCEPT
	iptables -A OUTPUT -o br-+ -j ACCEPT
	iptables -A OUTPUT -d 255.255.255.255 -j ACCEPT

	iptables -P FORWARD DROP
	iptables -A FORWARD -i tun+ -o virbr+ -j ACCEPT
	iptables -A FORWARD -i virbr+ -o tun+ -j ACCEPT
	iptables -A FORWARD -i virbr+ -o virbr+ -j ACCEPT
	iptables -A FORWARD -i vnet+ -o vnet+ -j ACCEPT
	iptables -A FORWARD -i virbr+ -o vnet+ -j ACCEPT
	iptables -A FORWARD -i vnet+ -o virbr+ -j ACCEPT

	ip6tables -P INPUT DROP
	ip6tables -A INPUT -i tun+ -j ACCEPT
	ip6tables -A INPUT -i lo -j ACCEPT

	ip6tables -P OUTPUT DROP
	ip6tables -A OUTPUT -o tun+ -j ACCEPT
	ip6tables -A OUTPUT -o lo -j ACCEPT

	ip6tables -P FORWARD DROP
}

function _edit_wg_config() {
	file=$1
	ip_address=$2

	file_is_wireguard=1
	if echo "$file" | grep -q ".ovpn"; then
		file_is_wireguard=0
	fi

	if ((file_is_wireguard)); then
		domain_or_ip=$(cat $file | grep Endpoint | awk -F'[=:]' '{print $2}' | awk '{$1=$1};1')
		if [ "$domain_or_ip" != "$ip_address" ]; then
			sed -i "/^Endpoint = /s/=\s*[^:]*:/= $ip_address:/" $file
		fi
	fi
}

function _pokeIP() {
	file=$1

	file_is_wireguard=1
	if echo "$file" | grep -q ".ovpn"; then
		file_is_wireguard=0
	fi

	domain_or_ip=""
	if ((file_is_wireguard)); then
		domain_or_ip=$(cat $file | grep Endpoint | awk -F'[=:]' '{print $2}' | awk '{$1=$1};1')
	else
		domain_or_ip=$(cat $file | grep remote | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq)
	fi
	is_ip_address=$(is_ip "$domain_or_ip")

	ip_address=""
	if ((is_ip_address)); then
		ip_address="$domain_or_ip"
	else
		iptables -A OUTPUT -o $INTERFACE -p udp -m multiport --dports 53,443,1637,51820,1300:1302,1194:1197 -d $DNS_SERVER -j ACCEPT
		iptables -A OUTPUT -o $INTERFACE -p tcp -m multiport --dports 53,443 -d $DNS_SERVER -j ACCEPT
		ip_address=$(dig +short @$DNS_SERVER "$domain_or_ip" | head -1)
		iptables -D OUTPUT -o $INTERFACE -p udp -m multiport --dports 53,443,1637,51820,1300:1302,1194:1197 -d $DNS_SERVER -j ACCEPT
		iptables -D OUTPUT -o $INTERFACE -p tcp -m multiport --dports 53,443 -d $DNS_SERVER -j ACCEPT
	fi

	is_ip_address=$(is_ip "$ip_address")
	if ((is_ip_address)); then
		iptables -A OUTPUT -o $INTERFACE -p udp -m multiport --dports 53,443,1637,51820,1300:1302,1194:1197 -d $ip_address -j ACCEPT
		iptables -A OUTPUT -o $INTERFACE -p tcp -m multiport --dports 53,443 -d $ip_address -j ACCEPT
		echo "$ip_address" >> $DIR/.poked_ips
		if ! [[ $EUID -ne 0 ]]; then
			chmod 666 $DIR/.poked_ips
		fi
	fi
	echo "$ip_address"
}

function _unpokeIPs() {
	while IFS= read -r line; do
		is_ip_address=$(is_ip "$line")
		if ((is_ip_address)); then
			ip_address="$line"
			iptables -D OUTPUT -o $INTERFACE -p udp -m multiport --dports 53,443,1637,51820,1300:1302,1194:1197 -d $ip_address -j ACCEPT
			iptables -D OUTPUT -o $INTERFACE -p tcp -m multiport --dports 53,443 -d $ip_address -j ACCEPT
		fi
	done < "$DIR/.poked_ips"

	echo "" > $DIR/.poked_ips
	if ! [[ $EUID -ne 0 ]]; then
		chmod 666 $DIR/.poked_ips
	fi

}


function _postip() {
	
	LOCAL_IP=$1
	VPN_IP=$2
	
	if (( IFTTT_ON )); then
		#echo "Running curl --connect-timeout 5 -o /dev/null -X POST -H \"Content-Type: application/json\" -d \"{\"message\": \"${IFTTT_MESSAGE}\",\"local-ip\": \"${LOCAL_IP}\",\"vpn-ip\": \"${VPN_IP}\"}\" https://maker.ifttt.com/trigger/${IFTTT_EVENT}/json/with/key/${IFTTT_KEY}"
		curl --connect-timeout 5 -o /dev/null -X POST -H "Content-Type: application/json" -d "{\"message\": \"${IFTTT_MESSAGE}\",\"local-ip\": \"${LOCAL_IP}\",\"vpn-ip\": \"${VPN_IP}\"}" https://maker.ifttt.com/trigger/${IFTTT_EVENT}/json/with/key/${IFTTT_KEY} 2>/dev/null
	fi
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
    local_subnet=$(/usr/bin/ip route | grep "$INTERFACE" | grep "/" | cut -d ' ' -f 1)

	iptables -D OUTPUT -d $local_subnet -p udp --dport 53 -j DROP 2>/dev/null
	iptables -D OUTPUT -d $local_subnet -p tcp --dport 53 -j DROP 2>/dev/null
	iptables -D INPUT -s $local_subnet -p udp --dport 53 -j DROP 2>/dev/null
	iptables -D INPUT -s $local_subnet -p tcp --dport 53 -j DROP 2>/dev/null
	iptables -D OUTPUT -d $local_subnet -j ACCEPT 2>/dev/null
	iptables -D INPUT -p tcp -m multiport --dports $INCOMING_PORTS -s $local_subnet -j ACCEPT 2>/dev/null
	iptables -D INPUT -p udp -m multiport --dports $INCOMING_PORTS -s $local_subnet -j ACCEPT 2>/dev/null
	iptables -D INPUT -s $local_subnet -j DROP 2>/dev/null
}

function _tablesAddLAN() {
    local_subnet=$(/usr/bin/ip route | grep "$INTERFACE" | grep "/" | cut -d ' ' -f 1)

	iptables -A OUTPUT -d $local_subnet -p udp --dport 53 -j DROP
	iptables -A OUTPUT -d $local_subnet -p tcp --dport 53 -j DROP
	iptables -A INPUT -s $local_subnet -p udp --dport 53 -j DROP
	iptables -A INPUT -s $local_subnet -p tcp --dport 53 -j DROP
	iptables -A OUTPUT -d $local_subnet -j ACCEPT
	iptables -A INPUT -p tcp -m multiport --dports $INCOMING_PORTS -s $local_subnet -j ACCEPT
	iptables -A INPUT -p udp -m multiport --dports $INCOMING_PORTS -s $local_subnet -j ACCEPT
	iptables -A INPUT -s $local_subnet -j DROP
}

function _updateeverything() {
	_updateip
	_updatestatus
}

function _updateip() {
	if [ "$PROVIDER" == "AirVPN" ]; then
		ipinfo=$(curl --connect-timeout 5 https://ipleak.net/json/ 2>/dev/null | jq -r '.ip, .type, .city_name')
	elif [ "$PROVIDER" == "AzireVPN" ]; then
		ipinfo=$(curl --connect-timeout 5 https://v4.api.azirevpn.com/v3/check 2>/dev/null | jq -r '.data.ip, .data.connected, .data.geo.city' | sed -e 's/true/AzireVPN/')
	else
		ipinfo=$(curl --connect-timeout 5 https://ipinfo.io/json 2>/dev/null | jq -r '.ip, .org, .city')
	fi
	curl_exit_status=$?

	connected=$(echo "$ipinfo" | grep -i "$PROVIDER" | wc -l)
	# if [ "$PROVIDER" == "AzireVPN" ]; then
	# 	connected=$(curl --connect-timeout 5 -s https://v4.api.azirevpn.com/v3/check | grep '"connected": true' | wc -l)
	# 	if [ "$connected" -gt 0 ]; then
    # 		connected=1
	# 	fi
	# fi

	ipinfo="${ipinfo}"$'\n'"${connected}"

	if [ $curl_exit_status -eq 0 ]; then
		while IFS= read -r line; do
    		if [ -z "$ip" ]; then
        		ip="$line"
    		elif [ -z "$typ" ]; then
        		typ="$line"
    		elif [ -z "$city" ]; then
        		city="$line"
    		elif [ -z "$connected" ]; then
        		connected="$line"
    		fi
		done <<< "$ipinfo"
	fi
	ip_old=""
	typ_old=""
	city_old=""
	connected_old=""
	if [[ -e "$DIR/.ipinfo" ]]; then
		ipinfo_old=$(cat "$DIR/.ipinfo")
		while IFS= read -r line; do
    		if [ -z "$ip_old" ]; then
        		ip_old="$line"
    		elif [ -z "$typ_old" ]; then
        		typ_old="$line"
    		elif [ -z "$city_old" ]; then
        		city_old="$line"
    		elif [ -z "$connected_old" ]; then
        		connected_old="$line"
    		fi
		done <<< "$ipinfo_old"
	fi

	printf "$ipinfo" > $DIR/.ipinfo
	if ! [[ $EUID -ne 0 ]]; then
		chmod 666 $DIR/.ipinfo	
	fi

	if ! [ "$ip" == "$ip_old" ]; then
		local_inet=$(ip a | grep ${INTERFACE} | grep inet | xargs)
		local_inet=($local_inet)
		local_ip=${local_inet[1]}
		local_ip=${local_ip%/*}
	
		if [ "$connected" == "0" ]; then
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
    	elif [ -z "$connected" ]; then
        	connected="$line"
    	fi
	done <<< "$ipinfo"

	connection_file=$(cat "$DIR/.last_serverfile")
	vpn_ip=$(cat "$DIR/$connection_file" | grep remote | head -n 1 | awk '{print $2}')
	
	local_inet=$(ip a | grep ${INTERFACE} | grep inet | xargs)
	local_inet=($local_inet)
	local_ip=${local_inet[1]}
	local_ip=${local_ip%/*}

	class="connected"
	color="#ffffff"
	home_ip=""
	if [ "$connected" == "0" ]; then
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
\"connected\":\"${connected}\",\
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
	if [ "$PROVIDER" == "AirVPN" ]; then
		ipinfo=$(curl --connect-timeout 5 https://ipleak.net/json/ 2>/dev/null | jq -r '.ip, .type, .city_name')
	else
		ipinfo=$(curl --connect-timeout 5 https://ipinfo.io/json 2>/dev/null | jq -r '.ip, .org, .city')
	fi
}

function _disconnect() {

	called_from=$1

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	wireguard_on=$(ip a | grep "$WG_IFACE" | wc -l)
	if ([ $wireguard_on -ne 0 ] && [ -e "$DIR/$WG_IFACE.conf" ]); then
		wireguard_on=1
	else
		wireguard_on=0
	fi
	
	if ! ([ $openvpn_on -eq 0 ] && [ $wireguard_on -eq 0 ]); then
		if ! [ $openvpn_on -eq 0 ]; then
			killall openvpn
		fi

		if ! [ $wireguard_on -eq 0 ]; then
			wg-quick down $DIR/$WG_IFACE.conf
			rm $DIR/$WG_IFACE.conf
		fi

		_unpokeIPs
	fi

	openvpn_on=$(ps -A | grep openvpn | wc -l)
	wireguard_on=$(ip a | grep "$WG_IFACE" | wc -l)
	if ([ $wireguard_on -ne 0 ] && [ -e "$DIR/$WG_IFACE.conf" ]); then
		wireguard_on=1
	else
		wireguard_on=0
	fi

	if [ $openvpn_on -eq 0 ]; then
		echo "Openvpn disconnected"
	fi

	if [ $wireguard_on -eq 0 ]; then
		echo "Wireguard disconnected"
	fi

}


function _check_openvpn() {
	server_file=$1

	is_ovpn=$(echo "$server_file" | grep ".ovpn" | wc -l)

	echo "$is_ovpn"
}


function connect() {

	_checkroot

	_disconnect "connect"

	if [ ! -d "$DIR" ]; then
		echo "$DIR does not exist"
		exit 1
	fi

	count=$(ls -a1 $DIR | grep ".conf\|.ovpn" | wc -l)

	if [ "$count" -eq 0 ]; then
		echo "No .conf or .ovpn files found."
		exit 1
	fi

	server_file=""
	if [[ "$1" = "new" ]]; then
		server_file=$(ls -1 $DIR | grep ".conf\|.ovpn" | grep -v "$WG_IFACE.conf" | fzf)
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

	poked_ip=$(_pokeIP "$DIR/$server_file")
	if [ "$poked_ip" == "" ]; then
		echo "Couldn't find IP in config file"
		exit 1
	fi

	echo "Connecting to $server_file..."

	is_openvpn=$(_check_openvpn $server_file)
	if (( is_openvpn )); then
		openvpn --script-security 2 --up /etc/openvpn/update-resolv-conf --down /etc/openvpn/update-resolv-conf --down-pre --config $DIR/$server_file --daemon
	else
		cp $DIR/$server_file $DIR/$WG_IFACE.conf
		_edit_wg_config "$DIR/$WG_IFACE.conf" "$poked_ip"
		wg-quick up $DIR/$WG_IFACE.conf
	fi

	old_file=$(cat "$DIR/.last_serverfile")
	if ! [[ "$old_file" = "$server_file" ]]; then
		echo "$server_file" > $DIR/.last_serverfile
		chmod 666 $DIR/.last_serverfile
	fi
}

function disconnect() {
	_checkroot

	_disconnect "disconnect"
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
}

function lan() {

	_checkroot

	if ! has_local_ip; then
  		echo "Interface $INTERFACE does not have a local IP Address. Doing nothing."
  		exit 1
	fi
	
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
}

function reset() {
	rm $DIR/.vpnips
	rm $DIR/.statusmessage
	rm $DIR/.ipinfo
	rm $DIR/.killswitch_status
	rm $DIR/.poked_ips
	rm $DIR/.lan_status
	rm $DIR/$WG_IFACE.conf
}

function update() {
	_updateeverything	
}

function init() {
	reset
	killswitch on
	while ! has_local_ip; do
  		echo "Waiting for a local IP address..."
  		sleep 1
	done
	connect
	lan $LAN_DEFAULT
    while ! check_internet_connectivity; do
  		echo "No internet connectivity. Waiting..."
  		sleep 1
	done
    _updateeverything
}

function init_killswitch() {
	reset
	killswitch on
}

function init_connect() {
	connect
	lan $LAN_DEFAULT
}

function init_check() {
	while ! check_internet_connectivity; do
  		echo "No internet connectivity. Waiting..."
  		sleep 1
	done
    _updateeverything
}

if [ "$1" == "check" ]; then
	check ${@:2:$#-1}
elif ([ "$1" == "connect" ] || [ "$1" == "on" ]); then
	connect ${@:2:$#-1}
	sleep 2
	_updateeverything
elif ([ "$1" == "disconnect" ] || [ "$1" == "off" ]); then
	disconnect ${@:2:$#-1}
	sleep 1
	_updateeverything
elif ([ "$1" == "killswitch" ] || [ "$1" == "ks" ]); then
	killswitch ${@:2:$#-1}
	sleep 1
	_updateeverything
elif [ "$1" == "lan" ]; then
	lan ${@:2:$#-1}
	_updatestatus
elif [ "$1" == "reset" ]; then
	reset ${@:2:$#-1}
elif [ "$1" == "update" ]; then
	update ${@:2:$#-1}
elif [ "$1" == "init" ]; then
	init ${@:2:$#-1}
elif [ "$1" == "init-killswitch" ]; then
	init_killswitch ${@:2:$#-1}
elif [ "$1" == "init-connect" ]; then
	init_connect ${@:2:$#-1}
elif [ "$1" == "init-check" ]; then
	init_check ${@:2:$#-1}
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
	printf	"\t init-killswitch\n"
	printf	"\t init-connect\n"
	printf	"\t init-check\n"
	exit 0
fi
