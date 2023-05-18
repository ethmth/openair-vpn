#!/bin/bash

VARS_FILE="vars/vars.conf"

cp vpn.sh vpn
cp vpn-listen.sh vpn-listen
cp vpn-serve.py vpn-serve

while IFS= read -r line; do
    key="${line%%=*}"
	sed -i "/$key=/c\\$line" vpn
	sed -i "/$key=/c\\$line" vpn-listen
	sed -i "/$key=/c\\$line" vpn-serve
done < "$VARS_FILE"

echo "Created script files vpn and vpn-listen from vpn.sh and vpn-listen.sh with variables from $VARS_FILE"
