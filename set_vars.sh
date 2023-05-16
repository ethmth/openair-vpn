#!/bin/bash

VARS_FILE="vars.conf"
SCRIPT_FILE="vpn.sh"

while IFS= read -r line; do
    key="${line%%=*}"
	sed -i "/$key=/c\\$line" $SCRIPT_FILE
done < "$VARS_FILE"

echo "Updated variables in $SCRIPT_FILE from $VARS_FILE"
