#!/bin/sh
# Count processes and netstat records and print out in Sysvik custom graph format
#
# To use with Sysvik
#	1. Install Sysvik (www.sysvik.com)
#	2. Copy this file to /etc/sysvik.d
#	3. Ensure its executable

echo -n "gauge processes="
ps auwx | wc | awk '{printf $1}'
echo " Running processes"
echo -n "gauge netstat="
netstat -na | wc |awk '{printf $1}'
echo " Netstat records"
echo "graph systemstuff processes,netstat Some systemstuff;;Stuff"
