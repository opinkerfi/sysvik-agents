#!/bin/sh
#
# Version: 20081008-01
# Monitors if sysvik-data is running and if not, tries to start it
# 
# This script is part of sysvik package.
###################################################################
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin
export PATH

NOW=`date +"%F %H:%M:%S"`
if ps ax | grep -v grep | grep sysvik-data > /dev/null
then
	echo "Everything is fine" > /dev/null
else
	echo "$NOW Sysvik-check: sysvik-data not running, starting it up" >> /var/log/sysvik.log
        if [ -f /etc/init.d/sysvikd ]
        then
                /etc/init.d/sysvikd start
        fi

        if [ ! -f /etc/init.d/sysvikd ]
        then
                /usr/sbin/sysvik-data -b -q 
        fi
fi
