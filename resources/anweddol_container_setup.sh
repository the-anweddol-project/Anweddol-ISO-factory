#!/bin/bash

# This is the setup script that the server will execute to
# administrate containers on its runtime.

export PATH=$PATH:/usr/sbin/

if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
	echo "Usage : $0 <username> <password> <new_listen_port>"
	exit

fi

if [ `/bin/id -u` -ne 0 ]; then
	echo "This script must be run as root"
	exit

fi

# Create new user and set the WELCOME.txt file on its home folder
useradd -c 'Anweddol container client user' -g sudo -s /bin/bash -p $(echo $2 | openssl passwd -6 -stdin) -m $1
mv /etc/WELCOME.txt "/home/$1/"

# Add entries on the SSH configuration file
sed -i "21i # Anweddol SSH server administration\nPort $3\n" /etc/ssh/sshd_config
sed -i "22i AllowUsers $1\nDenyUsers endpoint\n" /etc/ssh/sshd_config

# Clear the history and disable endpoint user
history -c
usermod -L endpoint

# Restart the ssh service
systemctl restart sshd.service