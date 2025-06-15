#!/bin/bash

clear
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
printf "| \033[1m p i S p o t   I n s t a l l a t i o n   S c r i p t \033[0m |"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo

echo -n "[ 1] Check and get 'piSpot.conf' configuration file... "
# Get piSpot configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/piSpot.conf"
if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    printf "[\033[31m!\033[0m]"
    echo "Config '$CONF_FILE' not found." >&2
    exit 1
fi
printf "[\033[32m✓\033[0m]"

echo -n "[ 2] Check & create required variables... "
# Check required variables for wrapper
REQUIRED_VARS=( \
    wifi_ifname \
    wifi_autoconnect \
    SSID \
    PASSWORD \
    dhcp4_start \
    dhcp4_stop \
    dhcp4_leasetime \
    dns_port \
    ipv4_address \
    ipv4_dns \
    ipv4_method \
    ipv6_dns \
    ipv6_method \
    WRAPPER_SOURCE \
    WRAPPER_LOCATION \
    WRAPPER_TARGET \
    WRAPPER_ENVIRONMENT )

MISSING=0
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Missing Variable(s): $var" >&2
        MISSING=1
    fi
done
if [[ $MISSING -ne 0 ]]; then
    printf "[\033[31m!\033[0m]"
    echo "Please check your $CONF_FILE file." >&2
    exit 1
fi
printf "[\033[32m✓\033[0m]"

echo -n "[ 3] Check for root privileges... "
# Check for root privileges
if [[ "$EUID" -ne 0 ]]; then
    printf "[\033[31m!\033[0m]"
	echo "Missing root privileges - use sudo...!" >&2
	exit 1
fi
printf "[\033[32m✓\033[0m]"

echo -n "[ 4] Check for wrapper template... "
# Check if the wrapper source file exists
if [[ ! -f "$WRAPPER_SOURCE" ]]; then
    printf "[\033[31m!\033[0m]"
    echo "Wrapper source file '$WRAPPER_SOURCE' does not exist." >&2
    exit 1
fi
printf "[\033[32m✓\033[0m]"

WRAPPER_DIR="$(dirname "$WRAPPER_LOCATION")" # Just the path of the wrapper destination
echo -n "[ 5] Create wrapper directory '$WRAPPER_DIR'... "
# Create directories if they do not exist
mkdir -p "$WRAPPER_DIR" || {
    printf "[\033[31m!\033[0m]"
    echo "Failed to create wrapper directory '$WRAPPER_DIR'." >&2
    exit 1
}
printf "[\033[32m✓\033[0m]"

# Inject variables into a temporary wrapper script
TMP_WRAPPER="$(mktemp)"
echo -n "[ 6] Create temporary wrapper '$TMP_WRAPPER'... "
cp "$WRAPPER_SOURCE" "$TMP_WRAPPER"
printf "[\033[32m✓\033[0m]"
echo -n "[ 7] Inject variables into temporary wrapper... "
sed -i "s|__IPV4ADDRESS__|$ipv4_address|g" "$TMP_WRAPPER"
sed -i "s|__IPV4DNS__|$ipv4_dns|g" "$TMP_WRAPPER"
sed -i "s|__IPV6DNS__|$ipv6_dns|g" "$TMP_WRAPPER"
sed -i "s|__DHCP4START__|$dhcp4_start|g" "$TMP_WRAPPER"
sed -i "s|__DHCP4STOP__|$dhcp4_stop|g" "$TMP_WRAPPER"
sed -i "s|__DHCP4LEASETIME__|$dhcp4_leasetime|g" "$TMP_WRAPPER"
sed -i "s|__DNSPORT__|$dns_port|g" "$TMP_WRAPPER"
sed -i "s|__WRAPPERTARGET__|$WRAPPER_TARGET|g" "$TMP_WRAPPER"
printf "[\033[32m✓\033[0m]"

echo -n "[ 8] Check on file action needs for wrapping... "
# Install or update the wrapper script
if [[ -f "$WRAPPER_LOCATION" ]]; then
    if ! cmp -s "$TMP_WRAPPER" "$WRAPPER_LOCATION"; then
        printf "[\033[33m!\033[0m]"
        echo "Differences detected between local wrapper and installed wrapper."
        read -p "Update Wrapper? [y/N] " reply
        if [[ "$reply" =~ ^[JjYy]$ ]]; then
            cp "$TMP_WRAPPER" "$WRAPPER_LOCATION"
            chmod +x "$WRAPPER_LOCATION"
            echo "Wrapper successful updated."
        else
            echo "Update cancelled." >&2
        fi
    else
        printf "[\033[32m✓\033[0m]"
        echo "Wrapper is up to date."
    fi
else
    cp "$TMP_WRAPPER" "$WRAPPER_LOCATION"
    chmod +x "$WRAPPER_LOCATION"
    printf "[\033[32m✓\033[0m]"
    echo "Wrapper installed: '$WRAPPER_LOCATION'."
fi
echo
rm -f "$TMP_WRAPPER"

echo -n "[ 9] Check on PATH action needs for wrapping... "
# actualize PATH variable
if grep -q "$WRAPPER_DIR" "$WRAPPER_ENVIRONMENT"; then
    printf "[\033[32m✓\033[0m]"
    echo "PATH '$WRAPPER_DIR' already exist in '$WRAPPER_ENVIRONMENT'."
else
    printf "[\033[33m!\033[0m]"
    echo -n "[10] Actualizing PATH '$WRAPPER_DIR' in '$WRAPPER_ENVIRONMENT'..."
    # Backup the original environment file - ONCE!
    if [[ ! -f "$WRAPPER_ENVIRONMENT.piSpot.bak" ]]; then
        printf "[\033[33m!\033[0m]"
        echo -n "[10] Creating backup of '$WRAPPER_ENVIRONMENT' as '$WRAPPER_ENVIRONMENT.piSpot.bak'."
        cp "$WRAPPER_ENVIRONMENT" "$WRAPPER_ENVIRONMENT.piSpot.bak"
        printf "[\033[32m✓\033[0m]"
    fi
    echo -n "[11] Actualizing PATH '$WRAPPER_DIR' in '$WRAPPER_ENVIRONMENT'... "
    sed -i "s|^PATH=\"\(.*\)\"|PATH=\"$WRAPPER_DIR:\1\"|" "$WRAPPER_ENVIRONMENT" || \
    echo "PATH=\"$WRAPPER_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" \
    >> "$WRAPPER_ENVIRONMENT"
    printf "[\033[32m✓\033[0m]"
    echo "PATH '$WRAPPER_DIR' in '$WRAPPER_ENVIRONMENT' actualized. Reboot needed!"
    echo
    read -p "Reboot now to apply changes? [y/N] " reboot_reply
    if [[ "$reboot_reply" =~ ^[YyJj]$ ]]; then
        echo "System rebooting - you need to run this installation script once again to finish the piSpot installation!"
        read -p "Press ENTER to reboot..."
        shutdown -r now
    else
        echo "Quitting setup - You need to reboot your system to apply changes!" >&2
        echo "After reboot you need to run this installation script once again to finish the piSpot installation!" >&2
        exit 1
    fi
fi


########## Setup Access Point ##########
echo
echo
echo -n "[12] Disconnect and remove '$SSID' - if exist... "
nmcli connection down "$SSID" 2>/dev/null || true
nmcli connection delete "$SSID" 2>/dev/null || true
printf "[\033[32m✓\033[0m]"
echo
echo -n "[13] Creating new '$SSID' AP connection... "
nmcli connection add type wifi \
    ifname "$wifi_ifname" \
    con-name "$SSID" \
    autoconnect "$wifi_autoconnect" \
    ssid "$SSID" \
    mode ap
printf "[\033[32m✓\033[0m]"
echo

# Ask for PASSWORD if PASSWORD is "piSpot1234" or len < 8
if [[ "$PASSWORD" == "piSpot1234" || ${#PASSWORD} -lt 8 ]]; then
    echo -n "[?] Please enter a new password for '$SSID' AP connection: "
    read -s PASSWORD
    echo
fi
# Check if PASSWORD has at least 8 characters
if [[ ${#PASSWORD} -lt 8 ]]; then
    printf "[\033[31m!\033[0m]"
    echo "Password must be at least 8 characters long." >&2
    echo "Please run this script again and enter a valid password." >&2
    exit 1
fi

echo -n "[14] Modify '$SSID' AP connection... "
nmcli connection modify "$SSID" \
    802-11-wireless.mode ap \
    802-11-wireless.band bg \
    ipv4.method "$ipv4_method" \
    ipv4.addresses "$ipv4_address"/24 \
    ipv6.method "$ipv6_method" \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "$PASSWORD" \
    wifi-sec.proto rsn \
    wifi-sec.pairwise ccmp \
    wifi-sec.group ccmp
printf "[\033[32m✓\033[0m]"
echo
echo -n "[15] Activating Access Point '$SSID'... "
nmcli connection up "$SSID"
printf "[\033[32m✓\033[0m]"


if [[ "$ipv4_method" == "shared" ]]; then
	printf "\033[1m[\033[32m✓\033[0m\033[1m]    p i S p o t   i n s t a l l a t i o n   f i n i s h e d.\033[0m"
	exit 0
fi

exit 1


# The Following is just for setting up if "ip4.method != shared"
# Some issues... especially on Raspberry Zero... Future stuff...
# DO NOT USE/TEST THIS YET! Many Variable Names are outdated!

: <<'OLD_DONT_USE'
# Upstream-Interface ermitteln
for TARGET_IP in 8.8.8.8 1.1.1.1; do
    UPSTREAM=$(ip route get "$TARGET_IP" 2>/dev/null | awk '{print $5; exit}')
    if [ -n "$UPSTREAM" ]; then
        echo "[+] Upstream erkannt über $TARGET_IP → Interface: $UPSTREAM"
        break
    fi
done

if [ -z "$UPSTREAM" ]; then
    echo "[!] Kein aktives Upstream-Interface erkannt. NAT-Konfiguration wird abgebrochen."
    exit 1
fi

echo "[+] Starte dnsmasq auf Port "$DNSport
pkill dnsmasq 2>/dev/null || true
dnsmasq \
  --interface="$IFACE" \
  --listen-address="$IPADDR" \
  --bind-interfaces \
  --dhcp-range="$DHCPstartIP","$DHCPendIP",12h \
  --port="$DNSport" \
  --no-resolv \
  --server=1.1.1.1 &

echo "[+] IPv4-Forwarding aktivieren..."
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[+] Setze iptables-Regeln (NAT + Forwarding)"
iptables -t nat -A POSTROUTING -o "$UPSTREAM" -j MASQUERADE
iptables -A FORWARD -i "$IFACE" -o "$UPSTREAM" -j ACCEPT
iptables -A FORWARD -i "$UPSTREAM" -o "$IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "[+] Erlaube eingehenden Port 22 auf $UPSTREAM – blockiere alles andere"
# Eingehende Verbindungen auf Port 22 erlauben (SSH)
iptables -A INPUT -i "$UPSTREAM" -p tcp --dport 22 -j ACCEPT
# Alles andere aus dem Internet blockieren
iptables -A INPUT -i "$UPSTREAM" -j DROP

echo "[✓] '$ipv4_method' piSpot Installation abgeschlossen"

exit 0




# VERY OLD SHIT  -  DO NOT USE
########## Setup/Control/Update Wrapper ##########

# Aktuelles Verzeichnis merken
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/piSpot.conf"

# Konfiguration einlesen
if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    echo "Konfigurationsdatei $CONF_FILE nicht gefunden." >&2
    exit 1
fi

# Prüfen ob benötigte Variablen definiert sind
REQUIRED_VARS=(DHCPstartIP DHCPendIP DNSport IPADDR ORIGINAL_BIN)
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Fehlende Konfigurationsvariable: $var" >&2
        exit 1
    fi
done

# Wrapper-Pfade aus der Konfiguration oder Defaults
WRAPPER_SOURCE="${WRAPPER_SOURCE:-$SCRIPT_DIR/dnsmasq.wrapper}"
WRAPPER_TARGET="${WRAPPER_TARGET:-/usr/sbin/dnsmasq}"

# Prüfen ob Root-Rechte vorliegen
if [[ "$EUID" -ne 0 ]]; then
    echo "Dieses Script muss als root ausgeführt werden." >&2
    exit 1
fi

# Wrapper vorbereiten (Konstanten im Wrapper ersetzen)
TMP_WRAPPER="$(mktemp)"
cp "$WRAPPER_SOURCE" "$TMP_WRAPPER"

# Konstanten ersetzen
sed -i "s|__IPADDR__|$IPADDR|g" "$TMP_WRAPPER"
sed -i "s|__DHCPSTART__|$DHCPstartIP|g" "$TMP_WRAPPER"
sed -i "s|__DHCPSTOP__|$DHCPendIP|g" "$TMP_WRAPPER"
sed -i "s|__DNSPORT__|$DNSport|g" "$TMP_WRAPPER"

# Wrapper bereits installiert?
if [[ -f "$ORIGINAL_BIN" && -f "$WRAPPER_TARGET" ]]; then
    echo "Wrapper scheint bereits installiert zu sein."

    if ! cmp -s "$TMP_WRAPPER" "$WRAPPER_TARGET"; then
        echo "Abweichung zwischen lokalem Wrapper und installiertem Wrapper erkannt."
        read -p "Wrapper aktualisieren? [j/N] " reply
        if [[ "$reply" =~ ^[Jj]$ ]]; then
            cp "$TMP_WRAPPER" "$WRAPPER_TARGET"
            chmod +x "$WRAPPER_TARGET"
            echo "Wrapper aktualisiert."
        else
            echo "Keine Änderungen vorgenommen."
        fi
    else
        echo "Wrapper ist aktuell. Keine Aktion erforderlich."
    fi
else
    echo "Wrapper ist noch nicht eingerichtet. Starte Einrichtung..."

    # Binary verschieben
    if [[ -x "$WRAPPER_TARGET" ]]; then
        mv "$WRAPPER_TARGET" "$ORIGINAL_BIN"
        echo "Original dnsmasq-Binary nach $ORIGINAL_BIN verschoben."
    else
        echo "Warnung: $WRAPPER_TARGET existiert nicht oder ist nicht ausführbar."
    fi

    # Wrapper installieren
    cp "$TMP_WRAPPER" "$WRAPPER_TARGET"
    chmod +x "$WRAPPER_TARGET"
    echo "Wrapper installiert unter $WRAPPER_TARGET."
fi

rm -f "$TMP_WRAPPER"
OLD_DONT_USE
