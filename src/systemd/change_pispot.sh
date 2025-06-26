#!/bin/bash
SSID="piSpot"
PASSWORD="9966909108154711xyz!"
IFACE="wlan0"
UPSTREAM=""
IPADDR="10.0.1.254"
DHCPstartIP="10.0.1.20"
DHCPendIP="10.0.1.200"
DNSport="53"
DNSupstream="86.54.11.13,86.54.11.213,2a13:1001::86:54:11:13,2a13:1001::86:54:11:213"


echo "[+] Starte dnsmasq auf Port ""$DNSport"
sudo pkill dnsmasq
sudo dnsmasq \
    --interface="$IFACE" \
    --listen-address="$IPADDR" \
    --dhcp-range="$DHCPstartIP","$DHCPendIP",12h \
    --port="$DNSport" \
    --server=86.54.11.13 \
    --server=86.54.11.213 \
    --server=2a13:1001::86:54:11:13 \
    --server=2a13:1001::86:54:11:213 \
    --dhcp-leasefile=/var/lib/NetworkManager/dnsmasq-"$IFACE".leases \
    --pid-file=/run/nm-dnsmasq-"$IFACE".pid \
    --no-hosts \
    --keep-in-foreground \
    --bind-interfaces \
    --except-interface=lo \
    --clear-on-reload \
    --strict-order \
    --conf-file=/dev/null &



exit 0

echo "[+] Starte dnsmasq auf Port ""$DNSport"
sudo pkill dnsmasq 
sudo dnsmasq \
  --interface="$IFACE" \
  --listen-address="$IPADDR" \
  --bind-interfaces \
  --dhcp-range="$DHCPstartIP","$DHCPendIP",12h \
  --port="$DNSport" \
  --no-resolv \
  --server="$DNSupstream"


echo "[+] IPv4-Forwarding aktivieren..."
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

echo "[+] Setze iptables-Regeln (NAT + Forwarding)"
sudo iptables -t nat -A POSTROUTING -o "$UPSTREAM" -j MASQUERADE
sudo iptables -A FORWARD -i "$IFACE" -o "$UPSTREAM" -j ACCEPT
sudo iptables -A FORWARD -i "$UPSTREAM" -o "$IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "[+] Erlaube eingehenden Port 22 auf $UPSTREAM – blockiere alles andere"
# Eingehende Verbindungen auf Port 22 erlauben (SSH)
# sudo iptables -A INPUT -i "$UPSTREAM" -p tcp --dport 22 -j ACCEPT
# Alles andere aus dem Internet blockieren
# sudo iptables -A INPUT -i "$UPSTREAM" -j DROP

echo "[✓] piSpot & NAT-Setup abgeschlossen"

