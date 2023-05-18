#!/bin/python3

from flask import Flask
from flask import request

PORT=5000
DIR="/home/me/.vpn"

app = Flask(__name__)

@app.route("/")
def home():
	try:
		file = open(f"{DIR}/.statusmessage", 'r')
		message = file.read()
	except:
		message="{\
\"ip\":\"Unknown\",\
\"vpnip\":\"Unknown\",\
\"homeip\":\"Unknown\",\
\"localip\":\"Unknown\",\
\"file\":\"Unknown\",\
\"type\":\"Unknown\",\
\"city\":\"Unknown\",\
\"text\":\"Status Error VPN\",\
\"messages\": [{\"label\": {\"text\":\"Status Error VPN\",\"color\":\"#ff0000\"},\"progress\":{\"value\":0}}],\
\"tooltip\":\"ip: Unknown\\ncity: Unknown\\nkillswitch: Unknown\",\
\"class\":[\"Unknown\"],\
\"alt\":\"Unknown\"\
}"
	return message

if __name__ == "__main__":
    app.run(port=5000, host="127.0.0.1")
