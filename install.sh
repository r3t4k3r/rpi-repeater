#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

DEBIAN_FRONTEND=noninteractive apt install -yq network-manager macchanger

echo "creating files"
echo '
HOTSPOT_DEVICE=wlan0
HOTSPOT_SSID=hotspot
HOTSPOST_PASS=12345678
NETWORK_DEVICE=wlan1
NETWORK_SSID=home
NETWORK_PASS=12345678
' > /etc/rpi-repeater.conf
chmod 666 /etc/rpi-repeater.conf

mkdir -p /opt/rpi-repeater
echo '
#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "delete existing connections"
nmcli connection delete "wifi"
nmcli connection delete "Hotspot"

echo "change mac"
macchanger -r $NETWORK_DEVICE
echo "start hotspot"
nmcli device wifi hotspot ifname $HOTSPOT_DEVICE ssid $HOTSPOT_SSID password $HOTSPOST_PASS
echo "connect to network"
nmcli connection add type wifi ifname $NETWORK_DEVICE con-name "wifi" ssid $NETWORK_SSID
nmcli connection up "wifi" password $NETWORK_PASS
' > /opt/rpi-repeater/runner.sh
chmod 755 /opt/rpi-repeater/runner.sh

echo '
#!/bin/bash
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

ENV=$(cat "$config_path" | tr "'\n"' "' "')
env $ENV ./$runner
' > /opt/rpi-repeater/wrapper.sh
chmod 755 /opt/rpi-repeater/wrapper.sh

echo '
Unit]
Description=Run rpi-repeater on boot

[Service]
Type=oneshot
User=root
ExecStart=/bin/bash /opt/rpi-repeater/wrapper.sh /etc/rpi-repeater.conf /opt/rpi-repeater/runner.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/rpi-repeater.service

echo "starting service"
systemctl enable rpi-repeater.service

echo "source: https://github.com/r3t4k3r/rpi-repeater"
echo "now, please edit /etc/rpi-repeater.conf"
echo "after that reboot device, or do systemctl start rpi-repeater.service"
