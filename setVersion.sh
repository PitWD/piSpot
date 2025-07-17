#!/bin/bash

SRC_DIR="$(pwd)/src"
NEXT_DIR="$(pwd)/versions/next"
PREV_DIR="$(pwd)/versions/prev"

DEV_GET="$(pwd)/GetDevSetup.sh"
PREV_GET="$(pwd)/GetPrevSetup.sh"
NEXT_GET="$(pwd)/GetNextSetup.sh"

FILE_LIST=(
    "$(pwd)/GetDevSetup.sh"
    "$(pwd)/GetNextSetup.sh"
    "$SRC_DIR/Install.sh"
    "$SRC_DIR/tui.lib"
    "$SRC_DIR/piSpot.conf"
    "$SRC_DIR/main/piSpot.down"
    "$SRC_DIR/main/piSpot.up"
    "$SRC_DIR/main/piSpot.state"
    "$SRC_DIR/main/piSpot.Uninstall"
    "$SRC_DIR/gsm/gsm.new"
    "$SRC_DIR/gsm/gsm.up"
    "$SRC_DIR/gsm/gsm.down"
    "$SRC_DIR/gsm/gsm.del"
    "$SRC_DIR/wlan/wlan.new"
    "$SRC_DIR/wlan/wlan.up"
    "$SRC_DIR/wlan/wlan.down"
    "$SRC_DIR/wlan/wlan.del"
    "$SRC_DIR/wlan/wlan.select"
    "$SRC_DIR/systemd/dnsmasq.restarter"
    "$SRC_DIR/systemd/systemd-restarter.service"
    "$SRC_DIR/systemd/tweak.manual"
)

source "$SRC_DIR/tui.lib"

APP_VERSION=$(iniGet "$NEXT_GET" "APP_VERSION")
APP_STATE=$(iniGet "$NEXT_GET" "APP_STATE")
APP_DATE=$(iniGet "$NEXT_GET" "APP_DATE")

iniSet "$PREV_GET" "APP_VERSION" "$APP_VERSION"
iniSet "$PREV_GET" "APP_STATE" "$APP_STATE"
iniSet "$PREV_GET" "APP_DATE" "$APP_DATE"

APP_NAME="piSpot"
APP_VERSION="0.0.3"
APP_STATE="dev" # alpha, beta, stable, dev
APP_DATE="17.07.2025"

# Loop all files in FILE_LIST
for file in "${FILE_LIST[@]}"; do
    # Replace version, date and state in the file
    iniSet "$file" "APP_VERSION" "$APP_VERSION"
    iniSet "$file" "APP_STATE" "$APP_STATE"
    iniSet "$file" "APP_DATE" "$APP_DATE"
done

# copy next to last version
cp -r "$NEXT_DIR/"* "$PREV_DIR/"

# copy src to next
cp -r "$SRC_DIR/"* "$NEXT_DIR/src/"