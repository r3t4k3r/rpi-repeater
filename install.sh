#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ ! -f /etc/rpi-repeater.conf ]; then
	echo "creating config"
	echo 'HOTSPOT_DEVICE=wlan0
	HOTSPOT_SSID=hotspot
	HOTSPOST_PASS=12345678
	NETWORK_DEVICE=wlan1
	NETWORK_SSID=home
	NETWORK_PASS=12345678
	HOSTNAME=router' > /etc/rpi-repeater.conf
	chmod 666 /etc/rpi-repeater.conf
else
	echo /etc/rpi-repeater.conf already exists, skip
fi

echo "installing the script"
mkdir -p /opt/rpi-repeater
echo '#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "delete existing connections"
nmcli connection delete "Wifi"
nmcli connection delete "Hotspot"

echo "changing mac and hostname"
random_mac="00:$(openssl rand -hex 5 | sed '\''s/\(..\)/\1:/g; s/:$//'\'')"
hostnamectl set-hostname $HOSTNAME

echo "start hotspot ssid $HOTSPOT_SSID pass $HOTSPOST_PASS using dev $HOTSPOT_DEVICE"
nmcli device wifi hotspot ifname $HOTSPOT_DEVICE ssid $HOTSPOT_SSID password $HOTSPOST_PASS

echo "connect to ssid $NETWORK_SSID pass $NETWORK_PASS using dev $NETWORK_DEVICE"
nmcli connection add type wifi ifname $NETWORK_DEVICE con-name "Wifi" ssid $NETWORK_SSID
nmcli connection modify "Wifi" wifi-sec.key-mgmt wpa-psk
nmcli connection modify "Wifi" wifi-sec.psk $NETWORK_PASS
nmcli connection modify "Wifi" 802-11-wireless.cloned-mac-address $random_mac
nmcli connection modify "Wifi" connection.autoconnect no
nmcli connection up "Wifi"
while true; do
	connected_to=$(nmcli con | grep Wifi | sed '\''s/[ ][ ]*/ /g'\'' | cut -d " " -f 4)
	if [ "$connected_to" == "--" ]; then
		echo disconected, restarting network device, changing mac
		nmcli connection delete "Wifi"
		nmcli device disconnect iface $NETWORK_DEVICE
		ip link set $NETWORK_DEVICE down
		ip link set $NETWORK_DEVICE up
		nmcli device connect $NETWORK_DEVICE
		random_mac="00:$(openssl rand -hex 5 | sed '\''s/\(..\)/\1:/g; s/:$//'\'')"
		hostnamectl set-hostname $HOSTNAME
		nmcli connection add type wifi ifname $NETWORK_DEVICE con-name "Wifi" ssid $NETWORK_SSID
		nmcli connection modify "Wifi" wifi-sec.key-mgmt wpa-psk
		nmcli connection modify "Wifi" wifi-sec.psk $NETWORK_PASS
		nmcli connection modify "Wifi" 802-11-wireless.cloned-mac-address $random_mac
		nmcli connection modify "Wifi" connection.autoconnect no
		nmcli connection up "Wifi"
	fi
	sleep 1
done

' > /opt/rpi-repeater/runner.sh
chmod 755 /opt/rpi-repeater/runner.sh

echo '#!/bin/bash
config_path=$1
runner=$2

if [ ! -f $config_path ]; then
	echo "Config file not found!"
	exit 1
fi
if [ ! -f $runner ]; then
	echo "Runner not found!"
	exit 1
fi

ENV=$(cat "$config_path" | tr '\''\n'\'' '\'' '\'')
env $ENV ./$runner' > /opt/rpi-repeater/wrapper.sh
chmod 755 /opt/rpi-repeater/wrapper.sh

echo '
[Unit]
Description=Run rpi-repeater on boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/bin/bash /opt/rpi-repeater/wrapper.sh /etc/rpi-repeater.conf /opt/rpi-repeater/runner.sh
RemainAfterExit=yes
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/rpi-repeater.service

echo "enable autostart service"
systemctl daemon-reload
systemctl enable rpi-repeater.service

echo ""
echo "source: https://github.com/r3t4k3r/rpi-repeater"
echo ""
echo "now, please edit /etc/rpi-repeater.conf"
echo "after that, reboot device, or do systemctl start rpi-repeater.service"
