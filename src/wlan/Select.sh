#!/bin/bash

# --- Standardwerte ---
WLAN_IF="wlan1"
SSID=""
PASSWD=""
SECURITY=""

# --- Argumente verarbeiten ---
for ARG in "$@"; do
    case "$ARG" in
        SSID=*) SSID="${ARG#SSID=}" ;;
        PASSWD=*) PASSWD="${ARG#PASSWD=}" ;;
        WLAN=*) WLAN_IF="${ARG#WLAN=}" ;;
    esac
done

# --- Prüfen ob Interface existiert ---
if ! ip link show "$WLAN_IF" >/dev/null 2>&1; then
    echo "❌ Interface $WLAN_IF nicht gefunden."
    exit 1
fi

# --- Automatik-Modus ---
if [[ -n "$SSID" ]]; then
    echo "[+] Versuche automatische Verbindung zu '$SSID' mit $WLAN_IF"

    if [[ -z "$PASSWD" ]]; then
        nmcli device wifi connect "$SSID" ifname "$WLAN_IF"
    else
        nmcli device wifi connect "$SSID" password "$PASSWD" ifname "$WLAN_IF"
    fi
    exit $?
fi

# --- Interaktiver Modus ---
echo "[+] Scanne verfügbare Netzwerke auf $WLAN_IF..."
nmcli device wifi rescan ifname "$WLAN_IF" >/dev/null 2>&1
sleep 1

# SSID + SECURITY + SIGNAL anzeigen
readarray -t NETWORKS < <(nmcli -f SSID,SECURITY,SIGNAL device wifi list ifname "$WLAN_IF" | tail -n +2 | sort -r -k3)

if [[ ${#NETWORKS[@]} -eq 0 ]]; then
    echo "⚠️ Keine Netzwerke gefunden."
    exit 1
fi

echo ""
printf "Verfügbare Netzwerke:\n"
for i in "${!NETWORKS[@]}"; do
    SSID_LINE=$(echo "${NETWORKS[$i]}" | awk '{$1=$1};1')  # Trim leading/trailing spaces
    printf "[%2d] %s\n" $((i+1)) "$SSID_LINE"
done

read -rp "🔍 Nummer des gewünschten Netzwerks: " SSID_INDEX
SELECTED_LINE="${NETWORKS[$((SSID_INDEX-1))]}"
SSID=$(echo "$SELECTED_LINE" | awk '{print $1}')
SECURITY=$(echo "$SELECTED_LINE" | awk '{print $2}')

if [[ "$SECURITY" == "--" || -z "$SECURITY" ]]; then
    echo "[+] Verbinde mit offenem Netzwerk '$SSID'..."
    nmcli device wifi connect "$SSID" ifname "$WLAN_IF"
else
    read -rsp "🔑 Passwort für '$SSID': " PASSWD
    echo
    echo "[+] Verbinde mit '$SSID'..."
    nmcli device wifi connect "$SSID" password "$PASSWD" ifname "$WLAN_IF"
fi
