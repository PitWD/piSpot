#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/piSpot.conf"

# Konfiguration einlesen
if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    echo "Konfigurationsdatei $CONF_FILE nicht gefunden." >&2
    exit 1
fi

if [[ -z "$WRAPPER_LOCATION" ]]; then
    echo "WRAPPER_LOCATION nicht definiert in $CONF_FILE." >&2
    exit 1
fi

# Root-Rechte erforderlich
if [[ "$EUID" -ne 0 ]]; then
	echo "Dieses Skript muss mit root-Rechten ausgeführt werden." >&2
	exit 1
fi


# Access Point entfernen
echo "[+] Down $SSID..."
nmcli connection down "$SSID"
echo "[+] Remove $SSID..."
nmcli connection delete "$SSID"

# Bei IPv4method ungleich shared
if [[ "$IPV4method" != "shared" ]]; then
    echo "[+] Beende dnsmasq falls aktiv..."
    pkill dnsmasq 2>/dev/null || true

    echo "[+] IPv4 Forwarding deaktivieren..."
    echo 0 > /proc/sys/net/ipv4/ip_forward

    echo "[+] Entferne iptables-Regeln..."
    iptables -t nat -D POSTROUTING -o "$UPSTREAM" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i "$IFACE" -o "$UPSTREAM" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$UPSTREAM" -o "$IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -i "$UPSTREAM" -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    iptables -D INPUT -i "$UPSTREAM" -j DROP 2>/dev/null || true
fi

# Wrapper entfernen
if [[ -f "$WRAPPER_LOCATION" ]]; then
    rm -f "$WRAPPER_LOCATION"
    echo "Wrapper $WRAPPER_LOCATION wurde entfernt."
else
    echo "Wrapper $WRAPPER_LOCATION war nicht vorhanden."
fi

# /etc/environment bereinigen
ENV_FILE="/etc/environment"
if grep -q "/usr/local/piSpot/bin" "$ENV_FILE"; then
    cp "$ENV_FILE" "$ENV_FILE.bak"
    sed -i 's|/usr/local/piSpot/bin:||g' "$ENV_FILE"
    echo "/etc/environment bereinigt. Bitte neu einloggen oder neu starten, damit die Änderung wirksam wird."

    read -p "System jetzt neu starten, um Umgebungsvariablen zu übernehmen? [j/N] " confirm
    if [[ "$confirm" =~ ^[Jj]$ ]]; then
        echo "System wird neu gestartet. Danach ggf. dieses Skript bei Bedarf erneut ausführen."
        read -p "Drücke ENTER zum Fortfahren..."
        reboot
    fi
else
    echo "Pfad war nicht in /etc/environment enthalten."
fi
