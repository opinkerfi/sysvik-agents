#!/bin/sh
#
# Version: 20201229-01
# 
# This script performs housekeeping stuff for Sysvik
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
	if [ -e /usr/bin/systemctl ]; then
		if [ ! -e /usr/lib/systemd/system//sysvik-data.service ]; then
			echo "$NOW Systemctl script for Sysvik missing. Creating" >> /var/log/sysvik.log
			# Systemctl file missing
			cp -f /var/lib/sysvik/sysvik-data.service /usr/lib/systemd/system//sysvik-data.service
			/usr/bin/systemctl daemon-reload
			/usr/bin/systemctl start sysvik-data.service
			/usr/bin/systemctl enable sysvik-data.service
			sleep 5
			/usr/bin/systemctl restart sysvik-data.service
		fi
	elif [ -f /etc/init.d/sysvikd ]
        then
		echo "$NOW Starting via initd" >> /var/log/sysvik-housekeeping.log
                /etc/init.d/sysvikd start
        fi
fi

# Check	for invalid version and	uninstall sysvik-3.2r3-4.noarch
if [[ -e /usr/bin/rpm && ! -e /var/lib/sysvik/sysvik-3.2r3-4.fix ]]; then
	if /usr/bin/rpm -q sysvik-3.2r3-4.noarch; then
		echo "$NOW Package sysvik-3.2r3-4.noarch installed, removing" >> /var/log/sysvik.log
		/usr/bin/rpm -e --justdb --noscripts sysvik-3.2r3-4.noarch
		/usr/bin/touch /var/lib/sysvik/sysvik-3.2r3-4.fix
	else
		/usr/bin/touch /var/lib/sysvik/sysvik-3.2r3-4.fix
	fi
fi
