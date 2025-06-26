#!/bin/bash

###  A P P  D E F I N I T I O N S  ###
APP_NAME="piSpot"
APP_VERSION="0.0.1"
APP_STATE="dev" # alpha, beta, stable, dev
APP_DATE="26.06.2025"


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
SYSD_INJECT_VARS=(
    "TWEAK_TARGET_DNS"
)
SYSD_INJECT_DEST=(
    "__TWEAKTARGETDNS__"
)

# Management files with individual variables to inject
tweak_manual_file="$SCRIPT_DIR/bin/tweak_manual.sh"

# List of local to copy files (templates to bin  /  )
local_src_FILES=(
    "$SCRIPT_DIR/systemd/tweak.manual"
)
local_dest_FILES=(
    "$tweak_manual_file"
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
clrLines() {
    local -i lines="$1"
    for ((i=0; i<lines; i++)); do
        printf "${csi}2K"
        printf "${csi}1E"
    done
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
    local srcLST=("${!2}")
    local dstLST=("${!3}")
    local destPRT="$destFile"
    if [[ "$destPRT" =~ ^/home/([^/]+) ]]; then
        destPRT="~${destPRT#"/home/${BASH_REMATCH[1]}"}"
    fi
    printAction
    printf "${escBold}Inject variables$escReset into '$destPRT'... "
    for i in "${!srcLST[@]}"; do
        src_var="${srcLST[$i]}"
        dest_placeholder="${dstLST[$i]}"
        if [[ -z "${!src_var}" ]]; then
            printNOK
            printf "\n Variable '$src_var' does not exist.\n\t" >&2
            printCheckReasonExit
        fi
        # Check if placeholder exists in the wrapper script
        if ! grep -q "$dest_placeholder" "$destFile"; then
            printNOK
            printf "\n Placeholder '$dest_placeholder' not found in '$destPRT'.\n\t" >&2
            printCheckReasonExit
        fi
        sed -i "s|${dest_placeholder}|${!src_var}|g" "$destFile"
    done
    printOK
    echo
}
getValidPassword() {
    local pwd="$1"
    local forbidden="$2"
    local pwd2="$1"
    if [[ ${#pwd} -lt 8 || "$pwd" == "$forbidden" ]]; then
        pwd=""
        while true; do
            printf "\tPlease enter a new password: "
            read -s pwd
            echo
            delLines 2
            printf "\tPlease verify the password: "
            read -s pwd2
            echo
            if [[ "$pwd" != "$pwd2" ]]; then
                printf "\tPasswords do not match. Please try again."
                UpCursor 2
                clrLines 2
                UpCursor 2
                continue
            fi
            if [[ ${#pwd} -lt 8 ]]; then
                printf "\tPassword must be at least 8 characters long. Please try again."
                UpCursor 2
                clrLines 2
                UpCursor 2
                continue
            fi
            break
        done
    fi
    UpCursor 2
    delLines 2
    eval $3='$pwd'
}
copyFiles() {
    # Function to loop copies
    local filesLST=("${!1}")
    local destLST=("${!2}")
    local -i locCnt=0
    local -i cnt=${#filesLST[@]}
    local -i fold=0
    printAction
    printf "Copying$escBlueBold $cnt ${escReset}local files... "
    SaveCursor 1 "\n"
    for i in "${!filesLST[@]}"; do
        if [[ $fold -eq 1 ]]; then
            UpCursor 1
            delLines 1
        fi
        local destPRT="${destLST[$i]}"
        if [[ "$destPRT" =~ ^/home/([^/]+) ]]; then
            destPRT="~${destPRT#"/home/${BASH_REMATCH[1]}"}"
        fi
        if ! cp "${filesLST[$i]}" "${destLST[$i]}" 2> /dev/null; then
            printf "\t$escRed$destPRT$escReset\n"
            locCnt=$((locCnt + 1))
        else
            printf "\t$destPRT\n"
            # If file ends with ".sh", make it executable
            [[ "${destLST[$i]}" == *.sh ]] && chmod +x "${destLST[$i]}" 2>/dev/null || true
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
    printf "Curl$escBlueBold $cnt ${escReset}files for $target/... "
    SaveCursor 1 "\n"
    for file in "${filesLST[@]}"; do
        if [[ $fold -eq 1 ]]; then
            UpCursor 1
            delLines 1
        fi
        if ! curl -s -o "$target/$file" "$url/$file"; then
            printf "\t$escRed$file$escReset\n"
            # Remove error file if empty
            if [[ -f "$target/$file" && ! -s "$target/$file" ]]; then
                rm -f "$target/$file"
            fi
            locCnt=$((locCnt + 1))
        else
            printf "\t$file\n"
            # If file ends with ".sh", make it executable
            [[ "$file" == *.sh ]] && chmod +x "$target/$file" 2>/dev/null || true
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
injectVARS "$tweak_manual_file" "TWEAK_INJECT_VARS[@]" "TWEAK_INJECT_DEST[@]"

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


