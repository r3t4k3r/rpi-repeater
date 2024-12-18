#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "delete existing connections"
nmcli connection delete "wifi"
nmcli connection delete "hotspot"

echo "change mac"
macchanger -r $NETWORK_DEVICE
echo "start hotspot"
nmcli device wifi hotspot ifname $HOTSPOT_DEVICE ssid $HOTSPOT_SSID password $HOTSPOST_PASS
echo "connect to network"
nmcli connection add type wifi ifname $NETWORK_DEVICE con-name "wifi" ssid $NETWORK_SSID
nmcli connection modify "wifi" wifi-sec.key-mgmt wpa-psk
nmcli connection modify "wifi" wifi-sec.psk $NETWORK_PASS
nmcli connection up "wifi"
# nmcli dev wifi connect $NETWORK_SSID password $NETWORK_PASS ifname $NETWORK_DEVICE

