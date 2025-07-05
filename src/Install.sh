#!/bin/bash

###  A P P  D E F I N I T I O N S  ###
APP_NAME="piSpot"
APP_VERSION="0.0.1"
APP_STATE="dev" # alpha, beta, stable, dev
APP_DATE="26.06.2025"


###  G L O B A L  -  Variables & tui.lib ###
# Get dir of script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TUI_AS_SYS="true"     # false = use user PATH, etc. ...
source "./tui.lib" || {
    printf "\t${escRedBold}Error${escReset}: Could not source tui.lib\n\n"
    exit 1
}

linesCNT=15 # leading for final, 2-4 for the final result, trailing for final, prompt
finalCNT=15 # leading for final, 2-4 for the final result, trailing for final, prompt
###  G L O B A L  -  Variables  ###


CONF_FILE="$SCRIPT_DIR/$APP_NAME.conf"
CONF_PRT="$CONF_FILE"  # For printing with ~

# If CONF_PRT starts with /home/<user>/, replace with ~
if [[ "$CONF_PRT" =~ ^/home/([^/]+)/ ]]; then
    CONF_PRT="~/${CONF_PRT#"/home/${BASH_REMATCH[1]}/"}"
fi

actionLen=2  
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
    "dhcp4_leasefile"
    "dns_port"
    "dns_pidfile"
    "ipv4_address"
    "ipv4_dns"
    "ipv4_method"
    "ipv6_dns"
    "ipv6_method"
    "TWEAK_USE"
    "TWEAK_SOURCE_DNS"
    "TWEAK_TARGET_DNS"
    "TWEAK_SOURCE_SERVICE"
    "TWEAK_TARGET_SERVICE"
    "TWEAK_DNSMASQ"
    "gsm_ifname"
    "gsm_name"
    "gsm_apn"
    "gsm_pin"
    "gsm_dial"    
    "gsm_user"
    "gsm_password"
    "gsm_autoconnect"
    "wlan_ifname"
    "wlan_autoconnect"
)
# List of variables to inject into the dnsmasq restart scripts
TWEAK_INJECT_VARS=(
    "wifi_ifname"
    "ipv4_address"
    "ipv4_dns"
    "ipv6_dns"
    "dhcp4_start"
    "dhcp4_stop"
    "dhcp4_leasetime"
    "dhcp4_leasefile"
    "dns_port"
    "dns_pidfile"
    "TWEAK_DNSMASQ"
)
TWEAK_INJECT_DEST=(
    "__IFACE__"
    "__IPV4ADDRESS__"
    "__IPV4DNS__"
    "__IPV6DNS__"
    "__DHCP4START__"
    "__DHCP4STOP__"
    "__DHCP4LEASETIME__"
    "__DHCP4LEASEFILE__"
    "__DNSPORT__"
    "__DNSPIDFILE__"
    "__TWEAKDNSMASQ__"
)
# List of variables to inject into the tweak piSpot.service file
SYSD_INJECT_VARS=(
    "TWEAK_TARGET_DNS"
)
SYSD_INJECT_DEST=(
    "__TWEAKTARGETDNS__"
)
# List of variables to inject into the (manual) gsm scripts
GSM_INJECT_VARS=(
    "gsm_ifname"
    "gsm_name"
    "gsm_apn"
    "gsm_pin"
    "gsm_dial"    
    "gsm_user"
    "gsm_password"
    "gsm_autoconnect"
)
GSM_INJECT_DEST=(
    "__IFNAME__"
    "__NAME__"
    "__APN__"
    "__PIN__"
    "__DIAL__"    
    "__USER__"
    "__PASSWORD__"
    "__AUTOCONNECT__"
)
# List of variables to inject into the (manual) wlan scripts
WLAN_INJECT_VARS=(
    "wlan_ifname"
    "wlan_autoconnect"
)
WLAN_INJECT_DEST=(
    "__IFNAME__"
    "__AUTOCONNECT__"
)

# Management files with individual variables to inject
tweak_manual_sh="$BIN_DIR/tweak_manual.sh"

# List of local to copy files (not to inject & single inject files /  )
local_src_FILES=(
    "$SCRIPT_DIR/tui.lib"
    "$SCRIPT_DIR/systemd/tweak.manual"
)
local_dest_FILES=(
    "$BIN_DIR/tui.lib"
    "$tweak_manual_sh"
)

FILES_LISTS=(
    "WLAN"
    "GSM"
)
WLAN_src_FILES=(
    "$SCRIPT_DIR/wlan/wlan.new"
    "$SCRIPT_DIR/wlan/wlan.del"
    "$SCRIPT_DIR/wlan/wlan.up"
    "$SCRIPT_DIR/wlan/wlan.down"
    "$SCRIPT_DIR/wlan/wlan.select"
)
WLAN_dest_FILES=(
    "$BIN_DIR/wlan_new.sh"
    "$BIN_DIR/wlan_del.sh"
    "$BIN_DIR/wlan_up.sh"
    "$BIN_DIR/wlan_down.sh"
    "$BIN_DIR/wlan_select.sh"
)
GSM_src_FILES=(
    "$SCRIPT_DIR/gsm/gsm.new"
    "$SCRIPT_DIR/gsm/gsm.del"
    "$SCRIPT_DIR/gsm/gsm.up"
    "$SCRIPT_DIR/gsm/gsm.down"
)
GSM_dest_FILES=(
    "$BIN_DIR/gsm_new.sh"
    "$BIN_DIR/gsm_del.sh"
    "$BIN_DIR/gsm_up.sh"
    "$BIN_DIR/gsm_down.sh"
)
###  A P P  D E F I N I T I O N S  ###


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


########## Setup Access Point ##########
# Check if nmcli is installed
printAction
printf "Check for$escBold nmcli$escReset command... "
if ! command -v nmcli &> /dev/null; then
    printNOK
    printf "\n\t'${escBold}nmcli$escReset' command not found.\n\t" >&2
    printf "Please install NetworkManager and try again.\n\n" >&2
    exit 1
fi
printOK
echo
# Check if the wifi interface is available
printAction
printf "Check for$escBold wifi interface$escReset '$wifi_ifname'... "
if ! nmcli device status | grep -q "$wifi_ifname"; then
    printNOK
    printf "\n\t'${escBold}$wifi_ifname$escReset' interface not found.\n\t" >&2
    printf "Please check your wifi interface name and try again.\n\t" >&2
    printCheckReasonExit
fi
printOK
echo
# Check if the wifi interface is connected - if yes, down it via its ssid
printAction
printf "Check if$escBold wifi interface$escReset '$wifi_ifname' is free... "
actSSID="$(nmcli -t -f NAME connection show --active | grep "$wifi_ifname" | head -n 1)"
if [[ -z "$actSSID" ]]; then
    printOK
    echo
else
    printWARN
    echo
    printAction
    printf "Down the active connection '$actSSID'... "
    nmcli connection down "$actSSID" || {
        printNOK
        printf "\n\tFailed to down the active connection '$actSSID'.\n\t" >&2
        printCheckReasonExit
    }
    printOK
    echo
    printAction
    printf "Delete the active connection '$actSSID'... "
    nmcli connection delete "$actSSID" || {
        printNOK
        printf "\n\tFailed to delete the active connection '$actSSID'.\n\t"
        printCheckReasonExit
    }
    printOK
    echo
fi
# Delete connection SSID - if exist
printAction
printf "Check if$escBold SSID$escReset '$SSID' is free... "
if nmcli connection show | grep -q "$SSID"; then
    printWARN
    echo
    printAction
    printf "Remove '$SSID' connection... "
    nmcli connection delete "$SSID" > /dev/null || {
        printNOK
        printf "\n\tFailed to delete '$SSID'.\n\t" >&2
        printCheckReasonExit
    }
    printOK
else
    printOK
fi
echo

# Ask for PASSWORD if PASSWORD is "piSpot1234" or len < 8
printAction
printf "Check if$escBold PASSWORD$escReset is valid... "
SaveCursor 1
if [[ "$PASSWORD" == "piSpot1234" || ${#PASSWORD} -lt 8 ]]; then
    printWARN
    echo
    getValidPassword "$PASSWORD" "piSpot1234" PASSWORD
fi
RestoreCursor 1
printOK
echo

printAction
printf "Creating new '$SSID' AP @ '$wifi_ifname' connection... "
nmcli connection add type wifi \
    ifname "$wifi_ifname" \
    con-name "$SSID" \
    autoconnect "$wifi_autoconnect" \
    ssid "$SSID" \
    mode ap \
    802-11-wireless.mode ap \
    802-11-wireless.band bg \
    ipv4.method "$ipv4_method" \
    ipv4.addresses "$ipv4_address"/24 \
    ipv6.method "$ipv6_method" \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "$PASSWORD" \
    wifi-sec.proto rsn \
    wifi-sec.pairwise ccmp \
    wifi-sec.group ccmp > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    printNOK
    printf "\n\tFailed to create '$SSID' AP connection.\n\t" >&2
    printCheckReasonExit
fi
printOK
echo

if [[ "$TWEAK_USE" == "yes" ]]; then
    # Check if the tweak source dns file exists
    printAction
    printf "Check '$escBold$TWEAK_SOURCE_DNS$escReset' template... "
    if [[ ! -f "$TWEAK_SOURCE_DNS" ]]; then
        printNOK
        printf "\n Template '$TWEAK_SOURCE_DNS' doesn't exist.\n\t" >&2
        printCheckReasonExit
    fi
    printOK
    echo

    # Create tweak directory...
    TWEAK_DIR="$(dirname "$TWEAK_TARGET_DNS")"
    printAction
    printf "Create tweak dir '$escBold$TWEAK_DIR$escReset'... "
    mkdir -p "$TWEAK_DIR" || {
        printNOK
        echo "\n Failed to create '$TWEAK_DIR'.\n\t" >&2
        printCheckReasonExit
    }
    printOK
    echo

    # Create temporary tweak file
    printAction
    TMP_TWEAK="$(mktemp)"
    printf "Create temporary tweak '$escBold$TMP_TWEAK$escReset'... "
    if [[ -z "$TMP_TWEAK" ]]; then
        printNOK
        echo "\n Failed to create temporary tweak.\n\t" >&2
        printCheckReasonExit
    else
        cp "$TWEAK_SOURCE_DNS" "$TMP_TWEAK"
    fi
    printOK
    echo

    # Inject variables into the tweak
    injectVARS "$TMP_TWEAK" "TWEAK_INJECT_VARS[@]" "TWEAK_INJECT_DEST[@]"
    # Install or update the tweak script
    printAction
    printf "Check on$escBold installation / updating$escReset tweak... "
    SaveCursor 1
    if [[ -f "$TWEAK_TARGET_DNS" ]]; then
        if ! cmp -s "$TMP_TWEAK" "$TWEAK_TARGET_DNS"; then
            printWARN
            printf "\n\tDiff. detected!$escGreen New$escReset:'$escBold$TMP_TWEAK$escReset'\
    $escYellow Old$escReset:'$escBold$TWEAK_TARGET_DNS$escReset'.\n\t"
            read -p "Update tweak? [y/N] " reply
            SaveCursor 2
            if [[ "$reply" =~ ^[JjYy]$ ]]; then
                RestoreCursor 1
                cp "$TMP_TWEAK" "$TWEAK_TARGET_DNS" || {
                    printNOK
                    RestoreCursor 2
                    printf "\n\tFailed to update '$TWEAK_TARGET_DNS'.\n\t" >&2
                    printCheckReasonExit
                }
                chmod +x "$TWEAK_TARGET_DNS"
                printOK
            else
                printWARN
                RestoreCursor 2
                printf "\n\tKept old '$TWEAK_TARGET_DNS'." >&2
            fi
        else
            printOK
            RestoreCursor 2
            printf "\n\t'$TWEAK_TARGET_DNS' is up to date."
        fi
    else
        cp "$TMP_TWEAK" "$TWEAK_TARGET_DNS" || {
            printNOK
            RestoreCursor 2
            printf "\n\tFailed to install '$TWEAK_TARGET_DNS'.\n\t" >&2
            printCheckReasonExit
        }
        chmod +x "$TWEAK_TARGET_DNS"
        printOK
    fi
    echo
    rm -f "$TMP_TWEAK"


    # Check if the tweak source system file exists
    printAction
    printf "Check '$escBold$TWEAK_SOURCE_SERVICE$escReset' template... "
    if [[ ! -f "$TWEAK_SOURCE_SERVICE" ]]; then
        printNOK
        printf "\n Tweak template '$TWEAK_SOURCE_SERVICE' does not exist.\n\t" >&2
        printCheckReasonExit
    fi
    printOK
    echo
    
    # Create tweak systemd directory...
    TWEAK_SYS_DIR="$(dirname "$TWEAK_TARGET_SERVICE")"
    printAction
    printf "Create tweak systemd dir '$escBold$TWEAK_SYS_DIR$escReset'... "
    mkdir -p "$TWEAK_SYS_DIR" || {
        printNOK
        echo "\n Failed to create '$TWEAK_SYS_DIR'.\n\t" >&2
        printCheckReasonExit
    }
    printOK
    echo
    
    # Create temporary tweak systemd file
    printAction
    TMP_TWEAK_SYS="$(mktemp)"
    printf "Create temporary tweak systemd '$escBold$TMP_TWEAK_SYS$escReset'... "
    if [[ -z "$TMP_TWEAK_SYS" ]]; then
        printNOK
        echo "\n Failed to create temporary tweak systemd file.\n\t" >&2
        printCheckReasonExit
    else
        cp "$TWEAK_SOURCE_SERVICE" "$TMP_TWEAK_SYS"
    fi
    printOK
    echo
    
    # Inject variables into the tweak systemd file
    injectVARS "$TMP_TWEAK_SYS" "SYSD_INJECT_VARS[@]" "SYSD_INJECT_DEST[@]"
    # Install or update the tweak systemd
    printAction
    printf "Check on$escBold installation / updating$escReset tweak systemd... "
    SaveCursor 1
    if [[ -f "$TWEAK_TARGET_SERVICE" ]]; then
        if ! cmp -s "$TMP_TWEAK_SYS" "$TWEAK_TARGET_SERVICE"; then
            printWARN
            printf "\n\tDiff. detected!$escGreen New$escReset:'$escBold$TMP_TWEAK_SYS$escReset'\
    $escYellow Old$escReset:'$escBold$TWEAK_TARGET_SERVICE$escReset'.\n\t"
            read -p "Update tweak systemd? [y/N] " reply
            SaveCursor 2
            if [[ "$reply" =~ ^[JjYy]$ ]]; then
                RestoreCursor 1
                cp "$TMP_TWEAK_SYS" "$TWEAK_TARGET_SERVICE" || {
                    printNOK
                    RestoreCursor 2
                    printf "\n\tFailed to update '$TWEAK_TARGET_SERVICE'.\n\t" >&2
                    printCheckReasonExit
                }
                printOK
            else
                printWARN
                RestoreCursor 2
                printf "\n\tKept old '$TWEAK_TARGET_SERVICE'." >&2
            fi
        else
            printOK
            RestoreCursor 2
            printf "\n\t'$TWEAK_TARGET_SERVICE' is up to date."
        fi
    else
        cp "$TMP_TWEAK_SYS" "$TWEAK_TARGET_SERVICE" || {
            printNOK
            RestoreCursor 2
            printf "\n\tFailed to install '$TWEAK_TARGET_SERVICE'.\n\t" >&2
            printCheckReasonExit
        }
        printOK
    fi
    echo
    rm -f "$TMP_TWEAK_SYS"
fi

# copy local files from local_src_FILES to local_dest_FILES
copyFiles "local_src_FILES[@]" "local_dest_FILES[@]"
# inject (where necessary) settings into the copies
injectVARS "$tweak_manual_sh" "TWEAK_INJECT_VARS[@]" "TWEAK_INJECT_DEST[@]"

# Loop FILES_LISTS to get the to copy and the to inject lists
for list in "${FILES_LISTS[@]}"; do
    src_var="${list}_src_FILES[@]"
    dest_var="${list}_dest_FILES[@]"
    # copy files from src to dest
    copyFiles "$src_var" "$dest_var"
    # inject variables into the copied files
    injectVARS "${!dest_var}" "${list}_INJECT_VARS[@]" "${list}_INJECT_DEST[@]"
done

printAction
printf "Upping Access Point '$SSID' @ '$wifi_ifname'... "
nmcli connection up "$SSID" > /dev/null 2>&1 || {
    printNOK
    printf "\n\tFailed to up '$SSID' AP connection.\n\t" >&2
    printCheckReasonExit
}
printOK
echo

if [[ "$TWEAK_USE" == "yes" ]]; then
    # Enable the tweak systemd service
    printAction
    printf "Daemon-Reload systemd... "
    if ! systemctl daemon-reload > /dev/null 2>&1; then
        printNOK
        printf "\n\tFailed to reload daemon.\n\t" >&2
        printCheckReasonExit
    fi
    printOK
    echo
    # Enable and start the tweak systemd service
    printAction
    printf "Start '$escBold$TWEAK_TARGET_SERVICE$escReset'... "
    if ! systemctl enable --now "$TWEAK_TARGET_SERVICE" > /dev/null 2>&1; then
        printNOK
        printf "\n\tFailed to enable and start the tweak service.\n\t" >&2
        printCheckReasonExit
    fi
    printOK
fi

echo
printf "\n\tInstallation/Update of$escBoldItalic $APP_NAME $APP_VERSION($APP_STATE)$escReset finished successfully!\n\n"


