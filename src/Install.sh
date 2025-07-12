#!/bin/bash

###  A P P  D E F I N I T I O N S  ###
APP_NAME="piSpot"
APP_VERSION="0.0.1"
APP_STATE="dev" # alpha, beta, stable, dev
APP_DATE="26.06.2025"


###  G L O B A L  -  Variables & tui.lib ###
# Get dir of script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUI_AS_SYS="true"     # false = use user PATH, etc. ...
source "./tui.lib" || {
    printf "\t${escRedBold}Error${escReset}: Could not source tui.lib\n\n"
    exit 1
}

linesCNT=30
finalCNT=30
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
printAction "Check for$escBold nmcli$escReset command... "
if ! command -v nmcli &> /dev/null; then
    printNOK
    printf "\n\t'${escBold}nmcli$escReset' command not found.\n\t" >&2
    printf "Please install NetworkManager and try again.\n\n" >&2
    exit 1
fi
printOK "\n"

# Check if dnsmasq is installed
# There may be a predefined binary in TWEAK_DNSMASQ - if not, we "which" the binary
printAction "Check for$escBold dnsmasq$escReset command... "
if ! [[ -n "$TWEAK_DNSMASQ" ]]; then
    TWEAK_DNSMASQ="$(which dnsmasq 2>/dev/null)"
    if [[ -z "$TWEAK_DNSMASQ" ]]; then
        printNOK
        printf "\n\t'${escBold}dnsmasq$escReset' command not found.\n\t" >&2
        printf "Please install dnsmasq and try again.\n\n" >&2
        exit 1
    fi
fi
if ! [[ -x "$(which $TWEAK_DNSMASQ 2>/dev/null)" ]]; then
    printNOK
    printf "\n\t'${escBold}$TWEAK_DNSMASQ$escReset' command not found.\n\t" >&2
    printf "Please check your TWEAK_DNSMASQ variable in the configuration file.\n\n" >&2
    exit 1
fi
printOK "\n"

# Ask for PASSWORD if PASSWORD is "piSpot1234" or len < 8
printAction "Check if AccessPoint$escBold password$escReset is valid... "
SaveCursor 1
if [[ "$PASSWORD" == "piSpot1234" || ${#PASSWORD} -lt 8 ]]; then
    printWARN "\n"
    getValidPassword "$PASSWORD" "piSpot1234" PASSWORD
fi
RestoreCursor 1
printOK "\n"

# Check if the wifi interface is available
printAction "Check for$escBold wifi$escReset interface '$escBold$wifi_ifname$escReset'... "
if ! nmcli device status | grep -q "$wifi_ifname"; then
    printNOK
    printf "\n\t${escRedBold}ERROR$escReset - interface not found.\n\t" >&2
    printf "Please check your wifi_ifname variable in the configuration file.\n\t" >&2
    printCheckReasonExit
fi
printOK "\n"

# Check if the wifi interface is connected - if yes, down it via its ssid
printAction "  Check if wifi '$wifi_ifname' is$escBold free$escReset... "
actSSID="$(nmcli -t -f NAME,DEVICE connection show --active | grep "$wifi_ifname" | head -n 1 | cut -d: -f1)"
if [[ -z "$actSSID" ]]; then
    printOK "\n"
else
    printWARN "\n"
    printAction "  Down a active connection '$escBold$actSSID$escReset'... "
    nmcli connection down "$actSSID" &> /dev/null || {
        printNOK
        printf "\n\t${escRedBold}ERROR$escReset - failed to down the active connection '$actSSID'.\n\t" >&2
        printCheckReasonExit
    }
    printOK "\n"
    printAction "  Delete connection '$escBold$actSSID$escReset'... "
    nmcli connection delete "$actSSID" &> /dev/null || {
        printNOK
        printf "\n\t${escRedBold}ERROR$escReset - failed to delete the active connection '$actSSID'.\n\t"
        printCheckReasonExit
    }
    printOK "\n"
fi

# Delete connection SSID - if exist (as non-active)
printAction "Check if SSID '$escBold$SSID$escReset' is free... "
if nmcli -t -f NAME connection show | grep -Fxq "$SSID"; then
    printWARN "\n"
    printAction "  Remove '$SSID' connection... "
    nmcli connection delete "$SSID" &> /dev/null || {
        printNOK
        printf "\n\t${escRedBold}ERROR$escReset - failed to delete '$SSID'.\n\t" >&2
        printCheckReasonExit
    }
    printOK
else
    printOK
fi
echo

printAction "  Create$escBold '$SSID' AP @ '$wifi_ifname'$escReset connection... "
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
printOK "\n"

if [[ "$TWEAK_USE" == "yes" ]]; then
    # Check if the tweak source dns file exists
    printAction "Check '$escBold$TWEAK_SOURCE_DNS$escReset' template... "
    if [[ ! -f "$TWEAK_SOURCE_DNS" ]]; then
        printNOK
        printf "\n\tTemplate '$TWEAK_SOURCE_DNS' doesn't exist.\n\t" >&2
        printCheckReasonExit
    fi
    printOK "\n"

    # Create tweak directory...
    TWEAK_DIR="$(dirname "$TWEAK_TARGET_DNS")"
    printAction "Check/Create tweaks binary dir '$escBold$TWEAK_DIR$escReset'... "
    mkdir -p "$TWEAK_DIR" || {
        printNOK
        echo "\n Failed to create '$TWEAK_DIR'.\n\t" >&2
        printCheckReasonExit
    }
    printOK "\n"

    # Create temporary tweak file
    TMP_TWEAK="$(mktemp)"
    cp "$TWEAK_SOURCE_DNS" "$TMP_TWEAK"
    # Inject variables into the tweak
    injectVARS "$TMP_TWEAK" "TWEAK_INJECT_VARS[@]" "TWEAK_INJECT_DEST[@]" "false"

    # Install or update the tweak script
    printAction "Check on$escBold install / update$escReset $TWEAK_TARGET_DNS... "
    SaveCursor 1 "\n"
    SaveCursor 2
    if [[ -f "$TWEAK_TARGET_DNS" ]]; then
        if ! cmp -s "$TMP_TWEAK" "$TWEAK_TARGET_DNS"; then
            RestoreCursor 1
            printWARN
            RestoreCursor 2
            printf "\n\tDiff. detected!$escGreen New$escReset:'$escBold$TMP_TWEAK$escReset'\
    $escYellow Old$escReset:'$escBold$TWEAK_TARGET_DNS$escReset'.\n\t"
            read -p "Update tweak? [y/N] " reply
            SaveCursor 3
            if [[ "$reply" =~ ^[JjYy]$ ]]; then
                RestoreCursor 1
                cp "$TMP_TWEAK" "$TWEAK_TARGET_DNS" || {
                    printNOK
                    RestoreCursor 3
                    printf "\tFailed to update '$TWEAK_TARGET_DNS'.\n\t" >&2
                    printCheckReasonExit
                }
                chmod +x "$TWEAK_TARGET_DNS"
                printOK
            else
                RestoreCursor 1
                printWARN
                RestoreCursor 3
                printf "\t$escYellowKept old '$TWEAK_TARGET_DNS'.$escReset\n" >&2
            fi
        else
            RestoreCursor 1
            printOK
            RestoreCursor 2
            printf "\t'$TWEAK_TARGET_DNS' is$escGreenBold UpToDate$escReset.\n"
        fi
    else
        cp "$TMP_TWEAK" "$TWEAK_TARGET_DNS" || {
            RestoreCursor 1
            printNOK
            RestoreCursor 2
            printf "\tFailed to install '$TWEAK_TARGET_DNS'.\n\t" >&2
            printCheckReasonExit
        }
        chmod +x "$TWEAK_TARGET_DNS"
        RestoreCursor 1
        printOK
        RestoreCursor 2
        printf "\t$escGreen'$TWEAK_TARGET_DNS' successful installed.$escReset\n"
    fi
    rm -f "$TMP_TWEAK"


    # Check if the tweak source system file exists
    printAction "Check '$escBold$TWEAK_SOURCE_SERVICE$escReset' template... "
    if [[ ! -f "$TWEAK_SOURCE_SERVICE" ]]; then
        printNOK
        printf "\n\tTweak template '$TWEAK_SOURCE_SERVICE' does not exist.\n\t" >&2
        printCheckReasonExit
    fi
    printOK "\n"
    
    # Create tweak systemd directory...
    TWEAK_SYS_DIR="$(dirname "$TWEAK_TARGET_SERVICE")"
    printAction "Check/Create tweaks system dir '$escBold$TWEAK_SYS_DIR$escReset'... "
    mkdir -p "$TWEAK_SYS_DIR" || {
        printNOK
        echo "\n\tFailed to create '$TWEAK_SYS_DIR'.\n\t" >&2
        printCheckReasonExit
    }
    printOK "\n"
    
    # Create temporary *.system file
    TMP_TWEAK_SYS="$(mktemp)"
    cp "$TWEAK_SOURCE_SERVICE" "$TMP_TWEAK_SYS"    
    # Inject variables into the the tweak systemd file
    injectVARS "$TMP_TWEAK_SYS" "SYSD_INJECT_VARS[@]" "SYSD_INJECT_DEST[@]" "false"

    # Install or update the tweak systemd
    printAction "Check on$escBold install / update$escReset $TWEAK_TARGET_SERVICE... "
    SaveCursor 1 "\n"
    SaveCursor 2
    if [[ -f "$TWEAK_TARGET_SERVICE" ]]; then
        if ! cmp -s "$TMP_TWEAK_SYS" "$TWEAK_TARGET_SERVICE"; then
            RestoreCursor 1
            printWARN
            RestoreCursor 2
            printf "\tDiff. detected!$escGreen New$escReset:'$escBold$TMP_TWEAK_SYS$escReset'\
    $escYellow Old$escReset:'$escBold$TWEAK_TARGET_SERVICE$escReset'.\n\t"
            read -p "Update tweak systemd? [y/N] " reply
            SaveCursor 3
            if [[ "$reply" =~ ^[JjYy]$ ]]; then
                RestoreCursor 1
                cp "$TMP_TWEAK_SYS" "$TWEAK_TARGET_SERVICE" || {
                    printNOK
                    RestoreCursor 3
                    printf "\tFailed to update '$TWEAK_TARGET_SERVICE'.\n\t" >&2
                    printCheckReasonExit
                }
                printOK
            else
                RestoreCursor 1
                printWARN
                RestoreCursor 3
                printf "\t${escYellow}Kept old '$TWEAK_TARGET_SERVICE'.$escReset\n" >&2
            fi
        else
            RestoreCursor 1
            printOK
            RestoreCursor 2
            printf "\t'$TWEAK_TARGET_SERVICE' is$escGreenBold UpToDate$escReset.\n"
        fi
    else
        cp "$TMP_TWEAK_SYS" "$TWEAK_TARGET_SERVICE" || {
            RestoreCursor 1
            printNOK
            RestoreCursor 2
            printf "\tFailed to install '$TWEAK_TARGET_SERVICE'.\n\t" >&2
            printCheckReasonExit
        }
        RestoreCursor 1
        printOK
        RestoreCursor 2
        printf "\t$escGreen'$TWEAK_TARGET_SERVICE' successful installed.$escReset\n"
    fi
    rm -f "$TMP_TWEAK_SYS"
fi

# copy local files from local_src_FILES to local_dest_FILES
copyFiles "local_src_FILES[@]" "local_dest_FILES[@]"
# inject (where necessary) settings into the copies
injectVARS "$tweak_manual_sh" "TWEAK_INJECT_VARS[@]" "TWEAK_INJECT_DEST[@]" "false"

# Loop FILES_LISTS to get the to copy and the to inject lists
for list in "${FILES_LISTS[@]}"; do
    src_var="${list}_src_FILES[@]"
    dest_var="${list}_dest_FILES[@]"
    # copy files from src to dest
    copyFiles "$src_var" "$dest_var" "$list"
    # inject variables into the copied files
    vars_cnt=$(eval "echo \${#${list}_INJECT_VARS[@]}")
    files_cnt=$(eval "echo \${#${list}_dest_FILES[@]}")
    printAction "Injecting$escBlueBold $vars_cnt$escReset vars into$escCyanBold $files_cnt$escBlueBold $list$escReset files... "
    SaveCursor 1 
    printWARN "\n"
    for files in "${!dest_var}"; do
        injectVARS "$files" "${list}_INJECT_VARS[@]" "${list}_INJECT_DEST[@]" "false"
    done
    SaveCursor 2
    RestoreCursor 1
    printOK
    RestoreCursor 2
done

printAction "Upping AccessPoint '$escBold$SSID' @ '$wifi_ifname$escReset'... "
nmcli connection up "$SSID" > /dev/null 2>&1 || {
    printNOK
    printf "\n\tFailed to up '$SSID' AP connection.\n\t" >&2
    printCheckReasonExit
}
printOK "\n"

if [[ "$TWEAK_USE" == "yes" ]]; then
    # Enable the tweak systemd service
    printAction "Daemon-${escBold}Reload$escReset systemd... "
    if ! systemctl daemon-reload > /dev/null 2>&1; then
        printNOK
        printf "\n\tFailed to reload daemon.\n\t" >&2
        printCheckReasonExit
    fi
    printOK "\n"
    # Enable and start the tweak systemd service
    printAction "Start '$escBold$TWEAK_TARGET_SERVICE$escReset'... "
    if ! systemctl enable --now "$TWEAK_TARGET_SERVICE" > /dev/null 2>&1; then
        printNOK
        printf "\n\tFailed to enable and start the tweak service.\n\t" >&2
        printCheckReasonExit
    fi
    printOK "\n"
fi

printf "\n\n Installation/Update of$escBoldItalic $APP_NAME $APP_VERSION($APP_STATE)$escReset finished successfully!\n\n"


