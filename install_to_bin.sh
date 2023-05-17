#!/bin/bash

LOCATIONS_FILE="vars/install_location.conf"
SCRIPT_NAME="vpn"

while IFS= read -r line; do
	if grep -q "home" <<< "$line"; then
        echo "Copying $SCRIPT_NAME to $line$SCRIPT_NAME"
		cp $SCRIPT_NAME $line$SCRIPT_NAME
		chmod +x $line$SCRIPT_NAME
    else
        echo "Copying $SCRIPT_NAME to $line$SCRIPT_NAME as root"
		sudo -k cp $SCRIPT_NAME $line$SCRIPT_NAME
		sudo chmod +x $line$SCRIPT_NAME
    fi
done < "$LOCATIONS_FILE"

rm $SCRIPT_NAME
