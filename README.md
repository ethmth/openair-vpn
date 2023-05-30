# Open AirVPN

An executable for managing openvpn connections on Linux with AirVPN.

## Requirements

You'll need `git` to clone the repo and a text editor like `nano` to edit the `vars/vars.conf` file.

### Cron

You'll need `cron` if you want to set up a cronjob to run on startup in the way these scripts are intended to function.

To install `cron` on Arch Linux, use the `cronie` package:

```sh
sudo pacman -S cronie
sudo systemctl enable cronie
```

Additionally required packages for vpn functionality and vpn-serve flask server:

```bash
openvpn
openresolv
python
python-flask
```

## Open AirVPN Setup

Subscribe to AirVPN, then download the OpenVPN configuration files:

1. Navigate to [https://airvpn.org/generator/](https://airvpn.org/generator/)
2. Select the appropriate options. For example, "Linux, OpenVPN (TCP), Other Device"
3. Go to "By Single Servers" and Invert Selection to select all servers.
4. Click generate then download the zip, which should be called `AirVPN.zip`
5. Move the zip file to your desired EMPTY (will get messy) directory, for example `~/.vpn/`

## Setup the Scripts

### Getting the Files

Ensure `git` is installed, then clone the git repo.

```sh
git clone https://github.com/ethmth/openair-vpn.git
cd openair-vpn/
```

Copy the sample `vars/vars.conf.example` file to `vars/vars.conf` and `vars/install_location.conf.example` to `vars/install_location.conf`

```sh
cp vars/vars.conf.example vars/vars.conf
cp vars/install_location.conf.example vars/install_location.conf
```

Edit `vars/vars.conf` with your desired values.

1. `DIR` should be the empty folder you saved `AirVPN.zip` into.
2. `DEFAULT_FILE` is the OpenVPN configuration that will be used if your last used connection isn't available, or if you specify `vpn connect default`. This doesn't really matter if you run `vpn connect new` on your first go and select your desired server, because the program will remember your last used server and connect to that one.
3. `INTERFACE` is your network interface (use `ip a` to list interfaces)
4. `IFTTT_KEY`, `IFTTT_EVENT`, `IFTTT_MESSAGE` are for optional IFTTT integration. To find your key, go to [ifttt.com/maker_webhooks](https://ifttt.com/maker_webhooks) and click **Documentation**. It should say "Your key is: <your_key>".
5. `REST_DNS` is for optional, experimental Rest DNS integration.

Edit `vars/install_location.conf` with your desired value(s). Simply leave `/usr/bin/` if you want the script to be installed globally.

When you're done editing the configuration files, install the executables to your
desired location by running:

```sh
./set_vars.sh
./install_to_bin.sh
```

## Using the Scripts

If you would like this script to run on startup, and take advantage of complete
functionality, I would recommend setting up a `cronjob` as root/sudo.

```sh
sudo crontab -e # Edit your crontab
```

Then, add the following lines, replacing the directory with the directory you installed
the executables into:

```
@reboot /usr/bin/vpn reset
@reboot /usr/bin/vpn lan off startup
@reboot /usr/bin/vpn killswitch on
@reboot /usr/bin/vpn connect startup
*/5 * * * * /usr/bin/vpn update
```

Your setup should be complete. Reboot to test out the setup.
