# If complete remove

if [ $1 == 0 ];then
# Uninstall / not upgrade
	# Systemd: Cleanup
	if [ -e /usr/lib/systemd/system//sysvik-data.service ]; then
		/usr/bin/systemctl stop sysvik-data.service
		/usr/bin/systemctl disable sysvik-data.service
	fi

	# Initrd: Cleanup
	if [[ -f /etc/init.d/sysvikd && -f /sbin/chkconfig ]]; then
	        /etc/init.d/sysvikd stop
	        /sbin/chkconfig --del sysvikd
	fi
fi

