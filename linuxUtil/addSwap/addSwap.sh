#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

swapSize=$1000

echo "count block size is ${swapSize}"
dd if=/dev/zero of=/var/swapfile bs=1M count=${swapSize}
chmod 600 /var/swapfile
mkswap /var/swapfile
swapon /var/swapfile
echo "/var/swapfile swap swap defaults 0 0" >>/etc/fstab
echo "----- Finish! swap size add $1 G -----"
swapon -s