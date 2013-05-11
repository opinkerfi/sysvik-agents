#!/bin/sh
# Installation program for Sysvik
#
#    Copyright (C) 2007-2013 Tryggvi Farestveit
#
#   This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
##############################################################################

# Location of important programs
CP="/bin/cp -f"
MKDIR="/bin/mkdir"
CHMOD="/bin/chmod"
LN="/bin/ln"

############### Do not edit below ###############

CRON=0;
$CP sysvik /usr/sbin/sysvik
$CP sysvik-data /usr/sbin/sysvik-data
$CP sysvik-check.sh /usr/sbin/sysvik-check.sh
$CP apwatch /usr/sbin/apwatch

if [ -d /etc/cron.d ]
then
$CP sysvik.cron /etc/cron.d/sysvik
$CHMOD 600 /etc/cron.d/sysvik
fi


if [ ! -d /etc/sysvik ] 
then
$MKDIR /etc/sysvik
fi

if [ ! -d /var/spool/sysvik ] 
then
$MKDIR /var/spool/sysvik
fi

if [ ! -d /var/lib/sysvik ] 
then
$MKDIR /var/lib/sysvik
fi
$CP lib/SVcore.pm /var/lib/sysvik/SVcore.pm


$CHMOD 750 /usr/sbin/sysvik /usr/sbin/apwatch /etc/sysvik /var/spool/sysvik /usr/sbin/sysvik-check.sh /usr/sbin/sysvik-data

if [ -f /etc/init.d/crond ] 
then
/etc/init.d/crond reload
CRON=1
fi

if [ -f /etc/init.d/cron ] 
then
/etc/init.d/cron reload
CRON=1
fi

if [ $CRON -eq 0 ]
then 
echo "Unable to reload crond. You will need to do it manually for Sysvik to be enabled"
fi

echo "Installation complete"
echo ""

if [ ! -f /usr/sbin/aplog ]
then
$LN -s /usr/sbin/sysvik /usr/sbin/aplog
fi


if [ ! -f /etc/sysvik/node.dat ]
then
echo "This seems to be new install. Please run sysvik -r as root to register this node to the Sysvik network. www.sysvik.com"
fi
