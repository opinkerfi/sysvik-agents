# Legacy cleanup
if [ -e /var/spool/sysvik/local.db ]; then
	/bin/mv /var/spool/sysvik/local.db /var/lib/sysvik/local.db
fi

if [ -e /etc/sysvik/node.dat ]; then
        /bin/chmod 750 /etc/sysvik/node.dat
fi

if [ -e /var/spool/sysvik/local.db ]; then
        /bin/mv /var/spool/sysvik/local.db /var/lib/sysvik/local.db
fi


# Reload cron
if [ -e /etc/init.d/crond ]; then
	/etc/init.d/crond reload
fi

if [ -e /etc/init.d/cron ]; then
	/etc/init.d/cron reload
fi

if [ ! -e /usr/sbin/aplog ]; then
        /bin/ln -s /usr/sbin/sysvik /usr/sbin/aplog
fi

if [ ! -e /usr/sbin/sysvik-diary ]; then
        /bin/ln -s /usr/sbin/sysvik /usr/sbin/sysvik-diary
fi

if [ ! -e /etc/sysvik/node.dat ]; then
	/bin/echo ""
	/bin/echo "You need to register this node by typing \"sysvik -r\""
fi

# Systemd check
if [ -e /usr/bin/systemctl ]; then
	# Systemd system
	cp -f /var/lib/sysvik/sysvik-data.service /usr/lib/systemd/system//sysvik-data.service
	/usr/bin/systemctl daemon-reload
	/usr/bin/systemctl start sysvik-data.service
	/usr/bin/systemctl enable sysvik-data.service
	sleep 5
	/usr/bin/systemctl restart sysvik-data.service
else
	# Init.d system
	cp -f /var/lib/sysvik/sysvikd /etc/init.d/sysvikd
	if [ -e /sbin/chkconfig ]; then
	        /sbin/chkconfig --add sysvikd
	fi
	if [ -e /etc/init.d/sysvikd ]; then
	        /etc/init.d/sysvikd start 
	fi
fi
