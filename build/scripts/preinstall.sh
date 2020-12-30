if [ -e /usr/sbin/aplog ]; then
        /bin/rm -f /usr/sbin/aplog
fi

#if [ -e /etc/cron.d/sysvik ]; then
#        /bin/rm -rf /etc/cron.d/sysvik
#
#	if [ -e /etc/init.d/crond ]; then
#		/etc/init.d/crond reload
#	fi
#
#	if [ -e /etc/init.d/cron ]; then
#		/etc/init.d/cron reload
#	fi
#fi

# Stop service before install
if [ -e /etc/init.d/sysvikd ]; then
        /etc/init.d/sysvikd stop
fi

if [ -e /usr/lib/systemd/system//sysvik-data.service ]; then
	/usr/bin/systemctl stop sysvik-data
fi


# Remove old broken version if installed
#if [ -e /usr/bin/rpm ]; then
#        if /usr/bin/rpm -qi sysvik-3.2r3-4.noarch; then
#                /usr/bin/rpm -e --justdb --noscripts sysvik-3.2r3-4.noarch
#	fi
#fi
