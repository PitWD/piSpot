#!/bin/bash

###  A P P  D E F I N I T I O N S  ###
APP_NAME="piSpot"
APP_VERSION="0.0.1"
APP_STATE="dev" # alpha, beta, stable, dev
declare -i actionLen=2  #  1,2,3 => [1],[ 1],[  1]
TARGET_DIR=""
REPO_URL=""
###  A P P  D E F I N I T I O N S  ###


###  G L O B A L  -  Variables  ###
declare -a CURSOR_Y
declare -a CURSOR_X
declare -i TERM_X=80
declare -i TERM_Y=24
declare -i errCnt=0
declare -i fileCNT=0
declare -i dirCNT=0
declare -i linesCNT=7 # leading for final, 2-4 for the final result, trailing for final, prompt
declare -i finalCNT=7 # leading for final, 2-4 for the final result, trailing for final, prompt
declare -i action=1
###  G L O B A L  -  Variables  ###


###  E S C  -  constants  ###
esc="\033"
csi="${esc}["
escBold="${csi}1m"
escItalic="${csi}3m"
escUnderline="${csi}4m"
escReverse="${csi}7m"
escHidden="${csi}8m"
escStrikethrough="${csi}9m"
escResetBold="${csi}21m"
escResetItalic="${csi}23m"
escResetUnderline="${csi}24m"
escResetReverse="${csi}27m"
escResetHidden="${csi}28m"
escResetStrikethrough="${csi}29m"
escFaint="${csi}2m"
escReset="${csi}0m"
escGreen="${csi}32m"
escRed="${csi}31m"
escYellow="${csi}33m"
escBlue="${csi}34m"
escCyan="${csi}36m"
escMagenta="${csi}35m"
escWhite="${csi}37m"
escBlack="${csi}30m"
escGray="${csi}90m"
escGreenBold="${escGreen}${escBold}"
escRedBold="${escRed}${escBold}"
escYellowBold="${escYellow}${escBold}"
escBlueBold="${escBlue}${escBold}"
escCyanBold="${escCyan}${escBold}"
escMagentaBold="${escMagenta}${escBold}"
escWhiteBold="${escWhite}${escBold}"
escBlackBold="${escBlack}${escBold}"
escGrayBold="${escGray}${escBold}"
escOK="$escGreenBold✔$escReset"
escNOK="$escRedBold✘$escReset"
escWARN="$escYellowBold☡$escReset"
###  E S C  -  constants  ###


###  F u n c t i o n s  - generic  ###
SaveCursor() {
    local idx="$1"
    local prt="$2"
    local pos
    # Request cursor position from terminal
    exec < /dev/tty
    printf "${csi}6n"
    # Read response: ESC [ row ; col R
    IFS=';' read -sdR -r pos
    pos="${pos#*[}" # Remove ESC[
    CURSOR_Y[$idx]="${pos%%;*}"      # Row
    CURSOR_X[$idx]="${pos##*;}"      # Column
    exec <&-
    if [[ -n "$prt" ]]; then
        printf "$prt"
    fi
}
RestoreCursor() {
    local idx="$1"
    # Set cursor position
    printf "${csi}%d;%dH" "${CURSOR_Y[$idx]}" "${CURSOR_X[$idx]}"
}
SetCursor() {
    local x="$1"
    local y="$2"
    # Set cursor position
    printf "${csi}%d;%dH" "${$y}" "${$x}"
}
UpCursor() {
    local -i lines="$1"
    # Move cursor up
    printf "${csi}%dA" "$lines"
}
DownCursor() {
    local -i lines="$1"
    # Move cursor down
    printf "${csi}%dB" "$lines"
}
LeftCursor() {
    local -i cols="$1"
    # Move cursor left
    printf "${csi}%dD" "$cols"
}
RightCursor() {
    local -i cols="$1"
    # Move cursor right
    printf "${csi}%dC" "$cols"
}
GetTermSize() {
    # Get terminal size
    if [[ -t 1 ]]; then
        read -r TERM_Y TERM_X < <(stty size)
    else
        TERM_Y=24
        TERM_X=80
    fi
}
printOK() {
    printf "[$escOK]"
}
printNOK() {
    printf "[$escNOK]"
}
printWARN() {
    printf "[$escWARN]"
}
printCNT() {
    local -i n="$1"   # Value to print
    local -i len="$2"  # Fixed Len for the value e.g. 3 for "00n", "  n"
    # Print a number with leading c or spaces
    if [[ "$len" -eq 0 ]]; then
        len=$actionLen
    fi
    if [[ "$n" -eq 0 ]]; then
        n=$action
        ((action += 1))
    fi
    local retVal="$(strFixNum "$n" "$len")"
    printf "[$escCyanBold%s$escReset]" "$retVal"
}
strFixNum() {
    local -i n="$1"   # Value
    local -i cnt="$2" # Fixed Len for the value e.g. 3 for "00n", "  n"
    local c="$3"      # Character to use for padding
    local out
    local -i len=${#n}
    [[ -z "$c" ]] && c=" "
    if [[ $n -lt 0 ]]; then
        # remove leading minus sign
        n="${n#-}"
        out="-"
    fi
    for ((i = len; i < cnt; i++)); do
        out+="$c"
    done
    out+="$n"
    printf "%s" "$out"
}
DelLines() {
    local -i lines="$1"
    # Delete lines from terminal
    if [[ $lines -gt 0 ]]; then
        printf "${csi}%dM" "$lines"
    fi
}
###  F u n c t i o n s  - specific  ###
DownloadFiles() {
    # Function to loop download
    local target="$1"
    local url="$2"
    local filesLST=("${!3}")
    local -i locCnt=0
    local -i cnt=${#filesLST[@]}
    local -i fold=0
    printf " "
    printCNT 
    printf " Wget$escBlueBold $cnt ${escReset}files for $target/... "
    SaveCursor 1 "\n"
    for file in "${filesLST[@]}"; do
        if [[ $fold -eq 1 ]]; then
            UpCursor 1
            DelLines 1
        fi
        if ! wget -q -O "$target/$file" "$url/$file"; then
            printf "\t$escRed$file$escReset\n"
            # Remove error file if empty
            if [[ -f "$target/$file" && ! -s "$target/$file" ]]; then
                rm -f "$target/$file"
            fi
            locCnt=$((locCnt + 1))
        else
            printf "\t$file\n"
        fi
        if [[ $((CURSOR_Y[1] + finalCNT + 1)) -gt TERM_Y ]]; then
            fold=1
        fi
    done
    if [[ $fold -eq 1 ]]; then
        UpCursor 1
        DelLines 1
    fi
    SaveCursor 2
    RestoreCursor 1
    if [[ $locCnt -gt 0 ]]; then
        if [[ $locCnt -eq ${#filesLST[@]} ]]; then
            printNOK
        else
            printWARN
        fi
    else
        printOK
    fi
    errCnt=$((errCnt + locCnt))
    RestoreCursor 2
    echo
    return $locCnt
}
makeDirs(){
    #Function to loop the to create directories
    local dirsList=("${!1}")
    local -i locCnt=0
    # Elements in dirs array
    local cnt=${#dirsList[@]}
    local -i fold=0
    printf " "
    printCNT
    printf " Creating & Checking$escBlueBold $cnt ${escReset}Directories... "
    SaveCursor 1 "\n"
    for dir in "${dirsList[@]}"; do
        if [[ $fold -eq 1 ]]; then
            UpCursor 1
            DelLines 1
        fi
        if ! mkdir -p "$dir"; then
            printf "\t$escRed$dir$escReset\n"
            locCnt=$((locCnt + 1))
        else
            printf "\t$dir\n"
        fi
        if [[ $((CURSOR_Y[1] + finalCNT + 1)) -gt TERM_Y ]]; then
            fold=1
        fi
        sleep 0.25 
    done
    if [[ $fold -eq 1 ]]; then
        UpCursor 1
        DelLines 1
    fi
    SaveCursor 2 "\n"
    RestoreCursor 1
    if [[ $locCnt -gt 0 ]]; then
        if [[ $locCnt -eq ${#dirsList[@]} ]]; then
            printNOK
        else
            printWARN
        fi
    else
        printOK
    fi
    RestoreCursor 2
    echo
    return $locCnt
}
###  F u n c t i o n s  ###


###  M a i n  ###
clear
GetTermSize
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
