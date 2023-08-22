#!/bin/bash

DIR="/home/me/.vpn"

ips=$(cat $DIR/*.ovpn | grep remote | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq)

# echo "$ips" | sort | uniq


DIR2="/home/me/Downloads/airvpn"

wg_ips=$(cat $DIR2/*.conf | grep "Endpoint" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq)

# echo "$ips"
# echo "$wg_ips"

# ips+="\n"
# ips+=$wg_ips
ips="$ips\n$wg_ips"
ips=$(echo -e "$ips" | sort | uniq)
# printf "$wg_ips \n $ips"

echo "$ips"