From a fresh Raspberry64-OS
	(sudo) user setup while 1st start

sudo raspi-config
	open ssh
	set wlan country
	set name "piSpot"

Missing Software
	sudo apt-get install iptables

Files / Folders to copy/replace
	copy (replace) folder "etc_ssh" to /etc/ssh 
		run fix_ssh_rights.sh 
		
	
