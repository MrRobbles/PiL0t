#!/bin/bash
# /etc/network/if-up.d/pil0t-network
# On boot: reconnect wifi if configured, else fall back to eth0 DHCP

LOG="/var/log/pil0t-network.log"
echo "$(date): PiL0t network startup" >> $LOG

rfkill unblock wifi 2>/dev/null
ip link set wlan0 up 2>/dev/null
sleep 1

if ! pgrep -x wpa_supplicant > /dev/null; then
    wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf 2>> $LOG
    sleep 5
else
    wpa_cli -i wlan0 reconfigure 2>> $LOG
    sleep 5
fi

SSID=$(iwgetid wlan0 --raw 2>/dev/null)
if [ -n "$SSID" ]; then
    echo "$(date): WiFi connected: $SSID" >> $LOG
    dhcpcd wlan0 2>> $LOG
else
    echo "$(date): WiFi failed, falling back to eth0 DHCP" >> $LOG
    ip link set eth0 up
    dhcpcd eth0 2>> $LOG
fi

echo "$(date): Done. eth0=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet )\S+') wlan0=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet )\S+')" >> $LOG
