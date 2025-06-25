echo -n " dnsmasq : ";
systemctl is-enabled dnsmasq
echo -n "  pihole : ";
systemctl is-enabled pihole-FTL


# This script collects network information from devices managed by NetworkManager
# Ensure nmcli is installed
# Check if nmcli is installed
if ! command -v nmcli &> /dev/null; then
    echo "nmcli command not found. Please install NetworkManager."
    exit 1
fi
# Check if awk is installed
if ! command -v awk &> /dev/null; then
    echo "awk command not found. Please install awk."
    exit 1
fi
# Check if column is installed
if ! command -v column &> /dev/null; then
    echo "column command not found. Please install util-linux."
    exit 1
fi



# Defining the fields to be extracted/created
fields="GENERAL.TYPE GENERAL.DEVICE GENERAL.IP-IFACE GENERAL.STATE STATE.ID \
        GENERAL.IP4-CONNECTIVITY IPV4CONN.ID GENERAL.IP6-CONNECTIVITY IPV6CONN.ID \
        GENERAL.NM-MANAGED GENERAL.AUTOCONNECT GENERAL.CONNECTION GENERAL.DRIVER GENERAL.DRIVER-VERSION \
        INTERFACE-FLAGS.UP INTERFACE-FLAGS.LOWER-UP INTERFACE-FLAGS.CARRIER \
        WIFI-PROPERTIES.WPA WIFI-PROPERTIES.WPA2 WIFI-PROPERTIES.AP WIFI-PROPERTIES.2GHZ WIFI-PROPERTIES.WPA2 \
        AP[1].IN-USE AP[1].BSSID AP[1].SSID AP[1].MODE AP[1].CHAN AP[1].RATE AP[1].SIGNAL AP[1].BARS AP[1].SECURITY \
        IP4.ADDRESS[1] IP4.GATEWAY IP4.ROUTE[1] IP4.ROUTE[2] IP4.DNS[1] IP4.DNS[2] \
        IP6.ADDRESS[1] IP6.ADDRESS[2] IP6.GATEWAY IP6.ROUTE[1] IP6.ROUTE[2] IP6.DNS[1] IP6.DNS[2]"
        n=$(echo $fields | wc -w)

# Define the types of devices to be included in the extraction
types="wifi gsm ethernet tunnel bridge"
t=$(echo $types | wc -w)

nmcli -t -f "GENERAL.TYPE,GENERAL.DEVICE,GENERAL.IP-IFACE,GENERAL.STATE,\
        GENERAL.IP4-CONNECTIVITY,GENERAL.IP6-CONNECTIVITY,\
        GENERAL.NM-MANAGED,GENERAL.AUTOCONNECT,GENERAL.CONNECTION,GENERAL.DRIVER,GENERAL.DRIVER-VERSION,\
        INTERFACE-FLAGS.UP,INTERFACE-FLAGS.LOWER-UP,INTERFACE-FLAGS.CARRIER,\
        WIFI-PROPERTIES.WPA,WIFI-PROPERTIES.WPA2,WIFI-PROPERTIES.AP,WIFI-PROPERTIES.2GHZ,WIFI-PROPERTIES.WPA2,AP,\
        IP4.ADDRESS,IP4.GATEWAY,IP4.ROUTE,IP4.DNS,\
        IP6.ADDRESS,IP6.GATEWAY,IP6.ROUTE,IP6.DNS" device show | \
        awk -F: -v fields="$fields" -v n="$n" -v types="$types" -v t="$t" '
        BEGIN {
            split(fields, fieldsARR, " ")
            split(types, typesARR, " ")
            typeOK = 0
        }
        NF > 1 {
            if (typeOK == 0) {
                for (i=1; i<=t; i++) {
                    if ($2 == typesARR[i]) {
                        typeOK = 1
                        break
                    }
                }
            }
            if (typeOK == 1) {
                val = $2
                for (i = 3; i <= NF; i++) {
                    # eventually fix ipv6 addresses with multiple colons
                    val = val ":" $i
                }
                for (i=1; i<=n; i++) {
                    if ($1 == fieldsARR[i]) {                        
                        if ($1 == "GENERAL.STATE" || $1 == "GENERAL.IP4-CONNECTIVITY" || $1 == "GENERAL.IP6-CONNECTIVITY") {
                            # Check on "num (txt1(txt2))" or "num (txt1)"
                            # extract num - and eventually patch num and txt2
                            num = val + 0                           # extract num
                            val = gensub("^[^ ]* ", "", 1, val)     # remove num
                            gsub(/^[ \t]+|[ \t]+$/, "", val)        # trim whitespace
                            gsub(/^\(|\)$/, "", val)                # remove leading and trailing parentheses
                            if ($1 == "GENERAL.STATE") {
                                if (val ~ /\)/) {
                                    # val looks like "txt1(txt2)"
                                    if (val ~ /externally|external/) {
                                        gsub(/externally|external/, "ext.", val)
                                        num++
                                    }
                                }
                            }
                            if ($1 == "GENERAL.STATE") {
                                state = "STATE.ID"
                            } else if ($1 == "GENERAL.IP4-CONNECTIVITY") {
                                state = "IPV4CONN.ID"
                            } else if ($1 == "GENERAL.IP6-CONNECTIVITY") {
                                state = "IPV6CONN.ID"
                            }                            
                            vals[state] = num
                        }
                        vals[$1] = val
                        break
                    }
                }
            }
        }
        NF==0 {
            if (typeOK == 1) {
                for (i=1; i<=n; i++) {
                    printf "%s", (i==1 ? "" : ";")
                    printf "%s", (fieldsARR[i] in vals ? vals[fieldsARR[i]] : "")
                }
                print ""
            }
            typeOK = 0
            delete vals
        }
        END {
            if (typeOK == 1) {
                for (i=1; i<=n; i++) { 
                    printf "%s", (i==1 ? "" : ";")
                    printf "%s", (fieldsARR[i] in vals ? vals[fieldsARR[i]] : "")
                }
                print ""
            }
        }'
