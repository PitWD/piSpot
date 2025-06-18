#!/bin/bash

###  A P P  D E F I N I T I O N S  ###
APP_NAME="piSpot"
APP_VERSION="0.0.1"
APP_STATE="dev" # alpha, beta, stable, dev
# Get dir of script and set expected app.conf
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/$APP_NAME.conf"
CONF_PRT="$CONF_FILE"  # For printing with ~

# If CONF_PRT starts with /home/<user>/, replace with ~
if [[ "$CONF_PRT" =~ ^/home/([^/]+)/ ]]; then
    CONF_PRT="~/${CONF_PRT#"/home/${BASH_REMATCH[1]}/"}"
fi

declare -i actionLen=2  #  1,2,3 => [1],[ 1],[  1]
TARGET_DIR=""
REPO_URL=""

# List of required variables in APP_NAME.conf
REQUIRED_VARS=(
    "wifi_ifname"
    "wifi_autoconnect"
    "SSID"
    "PASSWORD"
    "dhcp4_start"
    "dhcp4_stop"
    "dhcp4_leasetime"
    "dns_port"
    "ipv4_address"
    "ipv4_dns"
    "ipv4_method"
    "ipv6_dns"
    "ipv6_method"
    "WRAPPER_SOURCE"
    "WRAPPER_LOCATION"
    "WRAPPER_TARGET"
    "WRAPPER_SYSTEMD"
    "WRAPPER_CONF"
)
# List of variables to inject into the wrapper script
INJECT_VARS=(
    "ipv4_address"
    "ipv4_dns"
    "ipv6_dns"
    "dhcp4_start"
    "dhcp4_stop"
    "dhcp4_leasetime"
    "dns_port"
    "WRAPPER_TARGET"
)
INJECT_DEST=(
    "__IPV4ADDRESS__"
    "__IPV4DNS__"
    "__IPV6DNS__"
    "__DHCP4START__"
    "__DHCP4STOP__"
    "__DHCP4LEASETIME__"
    "__DNSPORT__"
    "__WRAPPERTARGET__"
)
###  A P P  D E F I N I T I O N S  ###


###  G L O B A L  -  Variables  ###
declare -a CURSOR_Y
declare -a CURSOR_X
declare -i TERM_X=80
declare -i TERM_Y=24
declare -i errCnt=0
declare -i fileCNT=0
declare -i dirCNT=0
declare -i linesCNT=15 # leading for final, 2-4 for the final result, trailing for final, prompt
declare -i finalCNT=15 # leading for final, 2-4 for the final result, trailing for final, prompt
declare -i action=1
###  G L O B A L  -  Variables  ###


###  E S C  -  constants  ###
esc="\033"
csi="${esc}["
escBold="${csi}1m"
escItalic="${csi}3m"
escUnderline="${csi}4m"
escDblUnderline="${csi}21m"
escReverse="${csi}7m"
escHidden="${csi}8m"
escStrikethrough="${csi}9m"
escBoldItalic="${csi}1;3m"
escResetBold="${csi}22m"
escResetFaint="${csi}22m"
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
    #exec <&-
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
printCheckReasonExit(){
    printf "${escBold}Please check the reason(s)!$escReset\n\n" >&2
    exit 1    
}
printAction(){
    printCNT $action $actionLen " " " "
    ((action += 1))
}
printCNT() {
    local -i n="$1"    # Value to print
    local -i len="$2"  # Fixed Len for the value e.g. 3 for "00n", "  n"
    local strLead="$3"
    local strTrail="$4"
    # Print a "Action-Counter"
    if [[ -n "$strLead" ]]; then
        printf "%s" "$strLead"
    fi
    local retVal="$(strFixNum "$n" "$len")"
    printf "[$escCyanBold%s$escReset]" "$retVal"
    if [[ -n "$strTrail" ]]; then
        printf "%s" "$strTrail"
    fi
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
delLines() {
    local -i lines="$1"
    # Delete lines from terminal
    if [[ $lines -gt 0 ]]; then
        printf "${csi}%dM" "$lines"
    fi
}
###  F u n c t i o n s  - specific  ###
getConfigFile(){
    printAction
    printf "Check & Get '$escBold$CONF_PRT$escReset' file... "
    if [[ -f "$CONF_FILE" ]]; then
        source "$CONF_FILE"
    else
        printNOK
        printf "\n\tConfig '$CONF_PRT' not found.\n\t" >&2
        printCheckReasonExit
    fi
    printOK
    echo    
}
testConfigFile(){
    # Check if all required variables are set
    local -i MISSING=0
    printAction
    printf "${escBold}Test variables$escReset in '$CONF_PRT'... "
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            printf "\n\tMissing Variable(s): $var" >&2
            MISSING=1
        fi
    done
    if [[ $MISSING -ne 0 ]]; then
        printNOK
        printf "\n\tMissing var(s) in '$CONF_PRT' file.\n\t" >&2
        printCheckReasonExit
    fi
    printOK
    echo
}
checkRoot(){
    printAction
    printf "Check for$escBold root$escReset privileges... "
    # Check for root privileges
    if [[ "$EUID" -ne 0 ]]; then
        printNOK
        printf "\n${escBold} Missing root privileges - start script with sudo...!$escReset\n\n" >&2
        exit 1
    fi
    printOK
    echo   
}
injectVARS(){
    local destFile="$1"
    printAction
    printf "${escBold}Inject variables$escReset into '$destFile'... "
    for i in "${!INJECT_VARS[@]}"; do
        src_var="${INJECT_VARS[$i]}"
        dest_placeholder="${INJECT_DEST[$i]}"
        if [[ -z "${!src_var}" ]]; then
            printNOK
            echo "\n Variable '$src_var' does not exist.\n\t" >&2
            printCheckReasonExit
        fi
        # Check if placeholder exists in the wrapper script
        if ! grep -q "$dest_placeholder" "$destFile"; then
            printNOK
            echo "\n Placeholder '$dest_placeholder' not found in '$destFile'.\n\t" >&2
            printCheckReasonExit
        fi
        sed -i "s|${dest_placeholder}|${!src_var}|g" "$destFile"
    done
    printOK
    echo
}
###  F u n c t i o n s  - just because they are part of lib  ###
downloadFiles() {
    # Function to loop download
    local target="$1"
    local url="$2"
    local filesLST=("${!3}")
    local -i locCnt=0
    local -i cnt=${#filesLST[@]}
    local -i fold=0
    printAction
    printf "Wget$escBlueBold $cnt ${escReset}files for $target/... "
    SaveCursor 1 "\n"
    for file in "${filesLST[@]}"; do
        if [[ $fold -eq 1 ]]; then
            UpCursor 1
            delLines 1
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
        delLines 1
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
    printAction
    printf "Creating & Checking$escBlueBold $cnt ${escReset}Directories... "
    SaveCursor 1 "\n"
    for dir in "${dirsList[@]}"; do
        if [[ $fold -eq 1 ]]; then
            UpCursor 1
            delLines 1
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
        delLines 1
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
echo
GetTermSize

# Header
printf "  $escCyanBold 🛈 $escReset ${escUnderline}Installation/Update of $escBoldItalic$APP_NAME$escResetBold $APP_VERSION($APP_STATE)...$escReset "
SaveCursor 0 "\n\n"
((linesCNT += 3)) # leading line, header line, and trailing line

# Check for root privileges
checkRoot

# Check and get configuration file
getConfigFile
# Check required variables in configuration file
testConfigFile


if [[ $WRAPPER_USE == "yes" ]]; then

    # Check if the wrapper source file exists
    printAction
    printf "Check for '$escBold$WRAPPER_SOURCE$escReset' template... "
    if [[ ! -f "$WRAPPER_SOURCE" ]]; then
        printNOK
        printf "\n Wrapper template '$WRAPPER_SOURCE' does not exist.\n\t" >&2
        printCheckReasonExit
    fi
    printOK
    echo

    # Create wrapper directory...
    WRAPPER_DIR="$(dirname "$WRAPPER_LOCATION")"
    printAction
    printf "Create wrapper dir '$escBold$WRAPPER_DIR$escReset'... "
    mkdir -p "$WRAPPER_DIR" || {
        printNOK
        echo "\n Failed to create '$WRAPPER_DIR'.\n\t" >&2
        printCheckReasonExit
    }
    printOK
    echo

    # Create temporary wrapper
    printAction
    TMP_WRAPPER="$(mktemp)"
    printf "Create temporary wrapper '$escBold$TMP_WRAPPER$escReset'... "
    if [[ -z "$TMP_WRAPPER" ]]; then
        printNOK
        echo "\n Failed to create temporary wrapper.\n\t" >&2
        printCheckReasonExit
    else
        cp "$WRAPPER_SOURCE" "$TMP_WRAPPER"
    fi
    printOK
    echo
    # Inject variables into the wrapper
    injectVARS "$TMP_WRAPPER"   

    # Install or update the wrapper script
    printAction
    printf "Check on$escBold installation / updating$escReset wrapper... "
    SaveCursor 1
    if [[ -f "$WRAPPER_LOCATION" ]]; then
        if ! cmp -s "$TMP_WRAPPER" "$WRAPPER_LOCATION"; then
            printWARN
            printf "\n\tDiff. detected!$escGreen New$escReset:'$escBold$TMP_WRAPPER$escReset'\
    $escYellow Old$escReset:'$escBold$WRAPPER_LOCATION$escReset'.\n\t"
            read -p "Update wrapper? [y/N] " reply
            SaveCursor 2
            if [[ "$reply" =~ ^[JjYy]$ ]]; then
                RestoreCursor 1
                cp "$TMP_WRAPPER" "$WRAPPER_LOCATION" || {
                    printNOK
                    RestoreCursor 2
                    printf "\n\tFailed to update '$WRAPPER_LOCATION'.\n\t" >&2
                    printCheckReasonExit
                }
                chmod +x "$WRAPPER_LOCATION"
                printOK 
                #printf "\n\tWrapper updated '$WRAPPER_LOCATION'."
            #else
                #printf "\n\tUpdate cancelled." >&2
            fi
        else
            printOK
            #printf "\n\t${escBold}Wrapper$escReset '$WRAPPER_LOCATION' is$escBold UpToDate$escReset."
        fi
    else
        cp "$TMP_WRAPPER" "$WRAPPER_LOCATION" || {
            printNOK
            printf "\n\tFailed to install '$WRAPPER_LOCATION'.\n\t" >&2
            printCheckReasonExit
        }
        chmod +x "$WRAPPER_LOCATION"
        printOK
        #printf "\n\tWrapper installed: '$WRAPPER_LOCATION'."
    fi
    echo
    rm -f "$TMP_WRAPPER"


    doReboot=0
    # Check on systemd override folder
    printAction
    printf "Check on $escBold$WRAPPER_SYSTEMD$escReset... "
    SaveCursor 1
    if [[ ! -d "$WRAPPER_SYSTEMD" ]]; then
        printWARN
        echo
        printAction
        printf "${escBold}Creating$escReset $WRAPPER_SYSTEMD... "
        mkdir -p "$WRAPPER_SYSTEMD" || {
            printNOK
            printf "\n\tFailed to create\n\t" >&2
            printf "     '$WRAPPER_SYSTEMD'.\n\t" >&2
            printCheckReasonExit
        }
        printOK
        echo
    else
        printOK
        echo
    fi

    # Check on systemd override file 
    SYSTEMD_CONF="$WRAPPER_SYSTEMD/$WRAPPER_CONF"
    printAction
    printf "Check on $escBold$WRAPPER_CONF$escReset file... "
    confIsNew=0
    if [[ ! -f "$SYSTEMD_CONF" ]]; then
        printWARN
        echo
        printAction
        printf "${escBold}Creating$escReset $WRAPPER_CONF file... "
        # Create the override file with the default content
        echo "PATH=\"$WRAPPER_DIR:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" > "$SYSTEMD_CONF" || {
            printNOK
            printf "\n\tFailed to create '$WRAPPER_CONF'.\n\t" >&2
            printCheckReasonExit
        }
        confIsNew=1
        doReboot=1
    fi
    printOK
    echo

    if [[ $confIsNew -eq 0 ]]; then
        # Check if the wrapper directory is already in the PATH
        printAction
        printf "Check if '$escBold$WRAPPER_DIR$escReset' is in '$WRAPPER_CONF'... "
        SaveCursor 1
        # Check if WRAPPER_LOCATION is in front of PATH in SYSTEMD_CONF
        if grep -q "^PATH=\"$WRAPPER_DIR:" "$SYSTEMD_CONF"; then
            printOK
            echo
            #printf "\n\tPATH '$WRAPPER_DIR' already exists in '$WRAPPER_CONF'.\n"
        else
            # Inject the WRAPPER_LOCATION in front of the PATH in WRAPPER_ENVIRONMENT
            printWARN
            echo
            # printAction
            # printf "Inject '$WRAPPER_DIR' in front of '$WRAPPER_CONF' PATH... "
            # SaveCursor 2
            # Backup the override.conf - ONCE!
            if [[ ! -f "$SYSTEMD_CONF.piSpot.bak" ]]; then
                printAction
                printf "${escBold}Backup '$WRAPPER_CONF' as '$escBold$WRAPPER_CONF.piSpot.bak$escReset'... "
                cp "$SYSTEMD_CONF" "$SYSTEMD_CONF.piSpot.bak" || {
                    printNOK
                    printf "\n\tFailed to backup '$WRAPPER_CONF'.\n\t" >&2
                    printCheckReasonExit
                }
                printOK
                echo
            fi
            printAction
            printf "${escBold}Injecting$escReset '$WRAPPER_DIR' in '$WRAPPER_CONF'... "
            # Add WRAPPER_DIR to the front of PATH in WRAPPER_ENVIRONMENT
            if ! sed -i "s|^PATH=\"\(.*\)\"|PATH=\"$WRAPPER_DIR:\1\"|" "$SYSTEMD_CONF"; then
                printNOK
                printf "\n\tFailed to actualize PATH in '$WRAPPER_CONF'.\n\t" >&2
                printCheckReasonExit
            fi
            printOK
            echo
            # printf "\n\tPATH '$WRAPPER_DIR' in '$SYSTEMD_CONF' actualized."
            doReboot=1
        fi
    fi
    echo
    if [[ $doReboot -eq 1 ]]; then
        printf "\t"
        read -p "Reboot now to apply changes? [y/N] " reboot_reply
        if [[ "$reboot_reply" =~ ^[YyJj]$ ]]; then
            printf "\n\t${escBold}System rebooting$escReset"
            printf "\n\tYou need to run this installation script "
            printf "\n\tonce again to finish the piSpot installation!\n\t"
            read -p "Press ENTER to reboot..."
            shutdown -r now
        else
            printf "\n\t${escBold}Quitting Setup Without ReBoot$escReset" >&2
            printf "\n\tYou need to reboot your system to apply changes!" >&2
            printf "\n\tAfter reboot you need to run this installation script " >&2
            printf "\n\tonce again to finish the piSpot installation!\n\n" >&2
            exit 1
        fi
    fi
    #UpCursor 1
fi

exit

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
