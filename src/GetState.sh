echo -n "lighttpd : ";
systemctl is-enabled lighttpd
echo -n " hostapd : ";
systemctl is-enabled hostapd
echo -n " dnsmasq : ";
systemctl is-enabled dnsmasq
echo -n "  pihole : ";
systemctl is-enabled pihole-FTL

