#!/bin/bash

VARS_FILE="vars/vars.conf"
SCRIPT_FILE="vpn.sh"
NEW_SCRIPT="vpn"

cp $SCRIPT_FILE $NEW_SCRIPT

while IFS= read -r line; do
    key="${line%%=*}"
	sed -i "/$key=/c\\$line" $NEW_SCRIPT
done < "$VARS_FILE"

echo "Created script file $NEW_SCRIPT from $SCRIPT_FILE with variables from $VARS_FILE"
