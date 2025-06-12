#!/bin/bash

# This script gets all development files to get a piSpot (un)installation done.
# This script loads the latest files from the piSpot repository on GitHub.
# This script is just for development purposes and should not be used in production.

# Manually download the GetDevSetup.sh script and run it to get the latest files and structure.
    # wget -q -O GetDevSetup.sh https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/GetDevSetup.sh
    # sudo bash GetDevSetup.sh

# Automatically download and run the GetDevSetup.sh script to get the latest files and structure.
    # sudo wget -q -O GetDevSetup.sh https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/GetDevSetup.sh | bash

# To wget files for ~/piSpot
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/dnsmasq.wrapper
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/Install.sh
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/Uninstall.sh
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/Spot-UP.sh
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/Spot-DOWN.sh
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/piSpot.conf
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/Config.sh
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/State.sh
# To wget files for ~/piSpot/wlan
# https://raw.githubusercontent.com/PitWD/piSpot/refs/heads/main/src/wlan/Select.sh