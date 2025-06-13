#!/bin/bash

# This script gets all files (in development  state) to get a piSpot (un)installation done.
# This script loads the latest files from the piSpot repository on GitHub.
# This script is just for development purposes and should not be used in "production".

# Manually download the GetDevSetup.sh script and run it to get the latest files and structure.
    # wget -q -O GetDevSetup.sh https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/GetDevSetup.sh
    # sudo bash GetDevSetup.sh

# Automatically download and run the GetDevSetup.sh script to get the latest files and structure.
    # sudo wget -q -O GetDevSetup.sh https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/GetDevSetup.sh | bash


# Define base URLs and target directories
REPO_URL="https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src"
TARGET_DIR="$HOME/piSpot"
wlandir="wlan"
gsmdir="gsm"
wrapperdir="wrapper"

# List of files names in REPO_URL to download
ROOT_FILES=(
    "Install.sh"
    "Uninstall.sh"
    "Up.sh"
    "Down.sh"
    "piSpot.conf"
    "Config.sh"
    "State.sh"
)
# List of file names in REPO_URL/$wlandir to download
WLAN_FILES=(
    "wlan_new.sh"
    "wlan_del.sh"
    "wlan_connect.sh"
    "wlan_disconnect.sh"
    "wlan_up.sh"
    "wlan_down.sh"
)
# List of file names in REPO_URL/$gsmdir to download
GSM_FILES=(
    "gsm_new.sh"
    "gsm_del.sh"
    "gsm_connect.sh"
    "gsm_disconnect.sh"
    "gsm_up.sh"
    "gsm_down.sh"
)
# List of file names in REPO_URL/$wrapperdir to download
WRAPPER_FILES=(
    "dnsmasq.wrapper"
    "wrapper.install.sh"
    "wrapper.uninstall.sh"
)

clear

# Create target directories if they do not exist
mkdir -p "$TARGET_DIR" "$TARGET_DIR/$wlandir" "$TARGET_DIR/$gsmdir" "$TARGET_DIR/$wraperdir" || \
    printf "Failed to create one or more directories \033[31m \
        \n\t$TARGET_DIR, \
        \n\t$TARGET_DIR/$wlandir, \
        \n\t$TARGET_DIR/$gsmdir, \
        \n\t$TARGET_DIR/$wrapperdir \
        \033[0m\n \
        \033[1mPlease check the reason!\033[0m" \
        >&2 && exit 1
printf "Successful created or existing directories \
    \n\t$TARGET_DIR, \
    \n\t$TARGET_DIR/$wlandir, \
    \n\t$TARGET_DIR/$gsmdir, \
    \n\t$TARGET_DIR/$wrapperdir \
    \n"

echo "Start downloading piSpot setup files (development state) to $TARGET_DIR."

# Download loop for the root files
for file in "${ROOT_FILES[@]}"; do
    wget -q -O "$TARGET_DIR/$file" "$REPO_URL/$file" || \
        printf "\033[31mFailed to download $file from $REPO_URL/$file\033[0m"
    echo "$file downloaded successfully."
done
# Download loop for the wlan files
for file in "${WLAN_FILES[@]}"; do
    wget -q -O "$WLAN_DIR/$file" "$REPO_URL/$wlandir/$file" || \
        printf "\033[31mFailed to download $file from $REPO_URL/$wlandir/$file\033[0m"
    echo "$file downloaded successfully."
done
# Download loop for the gsm files
for file in "${GSM_FILES[@]}"; do
    wget -q -O "$GSM_DIR/$file" "$REPO_URL/$gsmdir/$file" || \
        printf "\033[31mFailed to download $file from $REPO_URL/$gsmdir/$file\033[0m"
    echo "$file downloaded successfully."
done
# Download loop for the wrapper files
for file in "${WRAPPER_FILES[@]}"; do
    wget -q -O "$WRAPPER_DIR/$file" "$REPO_URL/$wrapperdir/$file" || \
        printf "\033[31mFailed to download $file from $REPO_URL/$wrapperdir/$file\033[0m"
    echo "$file downloaded successfully."
done

# Goto the target directory
cd "$TARGET_DIR" || \
    printf "Failed to change directory to \033[31m$TARGET_DIR.\033[0m\n \
    Downloading was not successful - probably...¯\\_(ツ)_/¯\n \
    \033[1mPlease check the reasons!\033[0m" \
    >&2 && exit 1

printf "All files have been downloaded to \033[32m$TARGET_DIR\033[0m."
