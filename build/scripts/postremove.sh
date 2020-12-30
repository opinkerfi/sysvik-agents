# Remove copied files

if [ $1 == 0 ];then
# Uninstall / not upgrade
	if [ -e /usr/lib/systemd/system//sysvik-data.service ]; then
		rm -f /usr/lib/systemd/system//sysvik-data.service
	fi

	if [ -e /etc/init.d/sysvikd ]; then
		rm -f /etc/init.d/sysvikd
	fi
fi
