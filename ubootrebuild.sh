#!/bin/bash

while [ -f /var/run/nightly-repo ]
do
	sleep 30m
	echo "Waiting ..."
done


# remove lock file on exit
trap '{ sudo rm -f -- "/var/run/nightly-repo"; }' EXIT
sudo sh -c 'echo $$ > /var/run/nightly-repo'

BLTPATH="/build/"
BETA="yes"
REPOSITORY_INSTALL="kernel,bsp,armbian-config,armbian-firmware"
${BLTPATH}compile.sh EXPERT="yes" IGNORE_HASH="yes" REPOSITORY_INSTALL="${REPOSITORY_INSTALL}" KERNEL_ONLY="yes" BETA="$BETA" BUILD_ALL="yes" BSP_BUILD="yes" MAKE_ALL_BETA="yes" BOOTONLY="yes"
