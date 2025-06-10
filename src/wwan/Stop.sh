sudo mmcli -m 0 --simple-disconnect
sudo pkill -f "udhcpc -i wwan0"
sudo ip addr flush dev wwan0
sudo ip link set wwan0 down

