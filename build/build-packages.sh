#!/bin/sh
# Execute this from build directory
VERSION=3.3r1
RELEASE=5
LICENSE=GPLv2
VENDOR="Opin Kerfi"
DESCRIPTION="Agent for Sysvik system management service, www.sysvik.com. Sysvik monitors the system and reports to the Sysvik network about current status which can be seen in the central web application located at www.sysvik.com."
URL="https://www.sysvik.com"
MAINTAINER="<sysvik@sysvik.com>"
CATEGORY=Monitoring
URL="https://www.sysvik.com"
EXTRA="" # -e for edit check
BUILD_ROOT="/tmp/sysvik-build"

echo "Current directory is $PWD"
CUR_DIR=$PWD
if [ -e $BUILD_ROOT ]; then
	echo "Remove $BUILD_ROOT/ before build-prep"
	exit;
else
	echo "Creating $BUILD_ROOT"
	mkdir $BUILD_ROOT
fi

# Create directories
mkdir $BUILD_ROOT/usr/sbin -p
mkdir $BUILD_ROOT/var/lib/sysvik -p
mkdir $BUILD_ROOT/usr/share/man/man8 -p
mkdir $BUILD_ROOT/etc/cron.d -p
mkdir $BUILD_ROOT/etc/sysvik/custom.d -p
mkdir $BUILD_ROOT/etc/sysvik/custom.d/examples -p
mkdir $BUILD_ROOT/var/spool/sysvik -p
mkdir $BUILD_ROOT/var/lib/sysvik -p

# Copy files to $BUILD_ROOT/
install -m 750 -o root -g root ../sysvik $BUILD_ROOT/usr/sbin/sysvik
install -m 750 -o root -g root ../lib/SVcore.pm $BUILD_ROOT/var/lib/sysvik/SVcore.pm
install -m 750 -o root -g root ../sysvik-data $BUILD_ROOT/usr/sbin/sysvik-data
install -m 750 -o root -g root ../sysvik-updatecheck $BUILD_ROOT/usr/sbin/sysvik-updatecheck
install -m 755 -o root -g root ../sysvik.8.man.gz $BUILD_ROOT/usr/share/man/man8/sysvik.8.gz
install -m 600 -o root -g root ../sysvik.cron $BUILD_ROOT/etc/cron.d/sysvik
install -m 755 -o root -g root ../init.d/sysvikd $BUILD_ROOT/var/lib/sysvik/sysvikd
install -m 755 -o root -g root ../systemd/sysvik-data.service $BUILD_ROOT/var/lib/sysvik/sysvik-data.service
install -m 755 -o root -g root ../init.d/initrd-functions $BUILD_ROOT/var/lib/sysvik/initrd-functions
install -m 755 -o root -g root ../sysvik-check.sh $BUILD_ROOT/usr/sbin/sysvik-check.sh
install -m 755 -o root -g root ../custom.d/examples/files-tmp.sh $BUILD_ROOT/etc/sysvik/custom.d/examples/files-tmp.sh
install -m 755 -o root -g root ../custom.d/examples/ipmi-power.pl $BUILD_ROOT/etc/sysvik/custom.d/examples/ipmi-power.pl
install -m 755 -o root -g root ../custom.d/examples/ipmi-temp.pl $BUILD_ROOT/etc/sysvik/custom.d/examples/ipmi-temp.pl
install -m 755 -o root -g root ../custom.d/examples/ps.sh $BUILD_ROOT/etc/sysvik/custom.d/examples/ps.sh

cd $BUILD_ROOT/
echo "Building RPM"
fpm -s dir -t rpm --url "$URL" -n "$VENDOR" --category "$CATEGORY" --license "$LICENSE" -m "$MAINTAINER" --description "$DESCRIPTION" -n sysvik --architecture noarch $EXTRA --iteration "$RELEASE" --version "$VERSION" --depends perl --before-install $CUR_DIR/scripts/preinstall.sh --after-install $CUR_DIR/scripts/postinstall.sh --before-remove $CUR_DIR/scripts/preremove.sh --after-remove $CUR_DIR/scripts/postremove.sh .
echo "Building DEB"
fpm -s dir -t deb --url "$URL" -n "$VENDOR" --category "$CATEGORY" --license "$LICENSE" -m "$MAINTAINER" --description "$DESCRIPTION" -n sysvik --architecture noarch $EXTRA --iteration "$RELEASE" --version "$VERSION" --depends perl --before-install $CUR_DIR/scripts/preinstall.sh --after-install $CUR_DIR/scripts/postinstall.sh --before-remove $CUR_DIR/scripts/preremove.sh --after-remove $CUR_DIR/scripts/postremove.sh .
echo "Done. See $BUILD_ROOT"
