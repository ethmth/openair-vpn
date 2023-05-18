#!/bin/bash

LOCATIONS_FILE="vars/install_location.conf"

while IFS= read -r line; do
	if grep -q "home" <<< "$line"; then
        echo "Copying vpn and vpn-listen to ${line}"
		cp vpn ${line}vpn
		chmod +x ${line}vpn
		cp vpn-listen ${line}vpn-listen
		chmod +x ${line}vpn-listen
		cp vpn-serve ${line}vpn-serve
		chmod +x ${line}vpn-serve
    else
        echo "Copying vpn and vpn-listen to $line as root"
		sudo -k cp vpn ${line}vpn
		sudo chmod +x ${line}vpn
		sudo cp vpn-listen ${line}vpn-listen
		sudo chmod +x ${line}vpn-listen
		sudo cp vpn-serve ${line}vpn-serve
		sudo chmod +x ${line}vpn-serve
    fi
done < "$LOCATIONS_FILE"

rm vpn
rm vpn-listen
rm vpn-serve
