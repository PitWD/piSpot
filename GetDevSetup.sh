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
APP_NAME="piSpot"
APP_VERSION="0.0.1"
APP_STATE="dev" # alpha, beta, stable, dev
TARGET_DIR="$HOME/.$APP_NAME"
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
###  e s c  -  constants  ###


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
    if [[ -z "$len" ]]; then
        len=$actionLen
    fi
    strFixNum "$n" "$len"
    local -i retVal=$?
    printf "[$escCyanBold${retVal}$escReset]"
}
strFixNum() {
    local -i n="$1"   # Value
    local -i len="$2" # Fixed Len for the value e.g. 3 for "00n", "  n"
    local c="$3"      # Character to use for padding
    [[ -z "$c" ]] && c=" "
    local out
    if [[ $n -lt 0 ]]; then
        # negative number, insert leading zeros
        out=$(printf "%0${len}d" $(( -n )))
        out="-$out"
        # alternatively, replace leading zeros with c
        [[ "$c" == "0" ]] && out="${out:1}" || out="${out:1}" | tr "0" "$c"
        [[ "$c" != "0" ]] && out="-"$(echo "${out:1}" | tr "0" "$c")
        #printf "%s" "$out"
    else
        # printf "%${len}d" "$n" | sed "s/ /$c/g"
        out=$(printf "%${len}d" "$n" | sed "s/ /$c/g")
    fi
    return $out
}
###  F u n c t i o n s  - specific  ###
DelLines() {
    local -i lines="$1"
    # Delete lines from terminal
    if [[ $lines -gt 0 ]]; then
        printf "${csi}%dM" "$lines"
    fi
}
DownloadFiles() {
    # Function to loop download
    local target="$1"
    local url="$2"
    local filesLST=("${!3}")
    local -i locCnt=0
    local -i cnt=${#filesLST[@]}
    local -i fold=0
    printf " "
    printCNT "$action"
    action=$((action + 1))
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
    printCNT "$action"
    action=$((action + 1))
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
echo
GetTermSize

# 'Analyze' job
dirCNT=${#TARGET_FOLDERS[@]}
#Loop FILES_LISTS to count files and stylish used lines while DownLoadFiles()
for lst in "${FILES_LISTS[@]}"; do
    varName="${lst}_FILES"
    arrLength=$(eval echo "\${#${varName}[@]}")
    fileCNT=$((fileCNT + arrLength))
    ((linesCNT += 2)) # header line and trailing line
done

# Header
printf " [${escCyanBold}i$escReset]$escBlueBold $fileCNT ${escReset}files$escItalic($APP_STATE)$escReset"
printf " in $escBlueBold$dirCNT$escReset folders for $escBold$escItalic$APP_NAME$escReset $APP_VERSION... "
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
    DelLines $dirCNT
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
    DownloadFiles "$dstPath" "$srcPath" $lstFiles[@]
    fold=0
    if [[ $linesCNT -gt TERM_Y ]]; then
        # files
        RestoreCursor 1
        DownCursor 1
        cnt=$(eval echo "\${#${lstFiles}[@]}")
        DelLines $cnt
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
        printf "\n$escRedBold ERROR:$escReset Downloading was not successful!\n\
    ${escBold}Please check the reason(s)!$escReset\n\n"
        exit 1
    else
        printWARN
        RestoreCursor 1
        printf "\n$escYellowBold WARNING:$escReset Some files were not successfully downloaded.\n\
    ${escBold}Please check the reason(s)!$escReset\n\n"
        exit 1
    fi
else
    printOK
    RestoreCursor 1
    printf "\n $escBold$escItalic$APP_NAME$escReset successfully downloaded to$escGreen $TARGET_DIR/$escReset... "
    printOK
    # If TARGET_DIR starts with $HOME, replace it with ~
    if [[ "$TARGET_DIR" == "$HOME/"* ]]; then
        TARGET_DIR="${TARGET_DIR/#$HOME/\~}"
    fi
    printf "\n$escBold You can now run the installation script:$escReset\n$escItalic\
    cd $TARGET_DIR\n\
    sudo ./Install.sh$escReset\n\n"
fi
###  F I N A L  ###

