#!/bin/bash

# This script gets all files to get a piSpot installation done.
# This script loads the latest files from the piSpot repository on GitHub.
# This script is just for development purposes and should not be used in "the wild".

# Manually download the GetDevSetup.sh script and run it to get the latest files and structure.
    # wget -q -O GetDevSetup.sh https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/GetDevSetup.sh
    # sudo bash GetDevSetup.sh

# Automatically download and run the GetDevSetup.sh script to get the latest files and structure.
    # sudo wget -q -O GetDevSetup.sh https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/GetDevSetup.sh | bash


###  A P P  D E F I N I T I O N S  ###
REPO_URL="https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src"
#REPO_URL="file:///home/pit/OneDrive/GIT/piSpot/src" # For local testing
APP_NAME="piSpot"
APP_VERSION="0.0.1"
APP_STATE="dev" # alpha, beta, stable, dev
APP_DATE="18.06.2025"
# Get dir of script and set expected app.conf
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/.$APP_NAME"
CONF_FILE="$TARGET_DIR/$APP_NAME.conf"

# If SCRIPT_PRT starts with /home/<user>, replace with ~
# For displaying paths in a user-friendly way.
SCRIPT_PRT="$SCRIPT_DIR"
if [[ "$SCRIPT_PRT" =~ ^/home/([^/]+) ]]; then
    SCRIPT_PRT="~${SCRIPT_PRT#"/home/${BASH_REMATCH[1]}"}"
fi
TARGET_PRT="$SCRIPT_PRT/.$APP_NAME"
CONF_PRT="$TARGET_PRT/$APP_NAME.conf"

declare -i actionLen=1  #  1,2,3 => [1],[ 1],[  1]

# List of repo directories
REPO_FOLDERS=(
    "$REPO_URL"
    "$REPO_URL/wlan"
    "$REPO_URL/gsm"
    "$REPO_URL/wrapper"
)
# List of target directories
TARGET_FOLDERS=(
    "$TARGET_DIR"
    "$TARGET_DIR/wlan"
    "$TARGET_DIR/gsm"
    "$TARGET_DIR/wrapper"
)
# prefix for the *_FILES lists
FILES_LISTS=(
    "src"
    "wlan"
    "gsm"
    "wrapper"
)

# List of main files
src_FILES=(
    "Install.sh"
    "Uninstall.sh"
    "Up.sh"
    "Down.sh"
    "piSpot.conf"
    "Config.sh"
    "State.sh"
)
# List of wlan files
wlan_FILES=(
    "wlan_new.sh"
    "wlan_del.sh"
    "wlan_connect.sh"
    "wlan_disconnect.sh"
    "wlan_up.sh"
    "wlan_down.sh"
)
# List of gsm files
gsm_FILES=(
    "gsm_new.sh"
    "gsm_del.sh"
    "gsm_connect.sh"
    "gsm_disconnect.sh"
    "gsm_up.sh"
    "gsm_down.sh"
)
# List of wrapper files
wrapper_FILES=(
    "dnsmasq.wrapper"
    "wrapper_install.sh"
    "wrapper_uninstall.sh"
    #"NA.sh"
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
###  F u n c t i o n s  - just because the are part of lib  ###
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
getValidPassword() {
    local pwd="$1"
    local forbidden="$2"
    local pwd2="$1"
    if [[ ${#pwd} -lt 8 || "$pwd" == "$forbidden" || "$pwd" == *[!a-zA-Z0-9\_\-] ]]; then
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
                sleep 1
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
            # Check for forbidden characters
            if [[ "$pwd" == *[!a-zA-Z0-9\_\-] ]]; then
                printf "\tPassword contains forbidden characters."
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
    printf "$pwd\n"
}
###  F u n c t i o n s  ###


###  M a i n  ###
clear
echo
GetTermSize


# 'Analyze' job
dirCNT=${#TARGET_FOLDERS[@]}
#Loop FILES_LISTS to count files and stylish used lines while downloadFiles()
for lst in "${FILES_LISTS[@]}"; do
    varName="${lst}_FILES"
    arrLength=$(eval echo "\${#${varName}[@]}")
    fileCNT=$((fileCNT + arrLength))
    ((linesCNT += 2)) # header line and trailing line
done

# Header
printf " ${escCyanBold} 🛈 $escReset$escBlueBold $fileCNT$escReset files in $escBlueBold$dirCNT$escReset"
printf " folders for $escBoldItalic$APP_NAME$escResetBold $APP_VERSION($APP_STATE)...$escReset "
SaveCursor 0 "\n\n"
((linesCNT += 3)) # leading line, header line, and trailing line

# Create/Check target directories
makeDirs TARGET_FOLDERS[@]
errCnt=$?
# Add count TARGET_FOLDERS cnt to fileCNT
fileCNT=$((fileCNT + dirCNT))


((linesCNT += fileCNT)) # Max lines without folding
if [[ $linesCNT -gt TERM_Y ]]; then
    # fold directories
    RestoreCursor 1
    DownCursor 1
    delLines $dirCNT
    ((linesCNT -= (dirCNT+1)))
    #DownCursor 1
fi


# Loop FILES_LISTS to download files
idx=0
fold=0
for lst in "${FILES_LISTS[@]}"; do
    lstFiles="${lst}_FILES"
    srcPath="${REPO_FOLDERS[$idx]}"
    dstPath="${TARGET_FOLDERS[$idx]}"
    downloadFiles "$dstPath" "$srcPath" $lstFiles[@]
    fold=0
    if [[ $linesCNT -gt TERM_Y ]]; then
        # files
        RestoreCursor 1
        DownCursor 1
        cnt=$(eval echo "\${#${lstFiles}[@]}")
        delLines $cnt
        ((linesCNT -= (cnt+1)))
        fold=1
    fi
    ((idx++))
done
if [[ $fold -eq 0 ]]; then
    UpCursor 1
fi
SaveCursor 1
###  M a i n  ###


###  F I N A L  ###
RestoreCursor 0
if [[ $errCnt -gt 0 ]]; then
    if [[ $errCnt -eq $fileCNT ]]; then
        printNOK
        RestoreCursor 1
        printf "\n$escRedBold ERROR:$escReset Downloading was not successful!\n\t" >&2
        printCheckReasonExit
    else
        printWARN
        RestoreCursor 1
        printf "\n$escYellowBold WARNING:$escReset Some files were not successfully downloaded.\n\t" >&2
        printCheckReasonExit
    fi
else
    printOK
    RestoreCursor 1
    printf "\n $escBold$escItalic$APP_NAME$escReset successfully downloaded to$escGreen $CONF_PRT/$escReset... "
    printOK
    printf "\n$escBold You can now run the installation script:$escReset\n$escItalic\
    cd $SCRIPT_PRT\n\
    sudo ./Install.sh$escReset\n\n"
fi
###  F I N A L  ###

