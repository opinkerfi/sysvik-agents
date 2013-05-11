#!/bin/sh
# Count files in /etc and /tmp and print out in Sysvik custom graph format
#
# To use with Sysvik
#	1. Install Sysvik (www.sysvik.com)
#	2. Copy this file to /etc/sysvik.d
#	3. Ensure its executable

echo -n "gauge files_tmp="
/usr/bin/find /tmp -type f | wc | awk '{printf $1}'
echo " /tmp"
echo -n "gauge files_etc="
/usr/bin/find /etc -type f | wc | awk '{printf $1}'
echo " /etc"

echo "graph files files_tmp,files_etc Files counting;;# files"

