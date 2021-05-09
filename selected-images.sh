#!/bin/bash

[[ -f selected-images.conf ]] && source selected-images.conf

cd ${BLTPATH}
git pull
BETA="no"
#REPOSITORY_INSTALL="u-boot,kernel,armbian-config,armbian-zsh,armbian-firmware"
REBUILD_IMAGES="pinebook-pro"
#,pinebook-pro,station-p1,station-m1"

#if [[ ${BETA} == "no" ]]; then
#	git checkout master -f
#	rm -f userpatches/targets.conf
#fi

#rm userpatches/targets.conf

#[[ -n ${VERZ} ]] && echo $VERZ >${BLTPATH}VERSION

#${BLTPATH}compile.sh single IGNORE_HASH="yes" REPOSITORY_INSTALL="${REPOSITORY_INSTALL}" REBUILD_IMAGES="${REBUILD_IMAGES}" KERNEL_ONLY="yes" BETA="$BETA" BUILD_ALL="yes" BSP_BUILD="yes" MAKE_ALL_BETA="yes"
${BLTPATH}compile.sh single ARMBIAN_MIRROR="https://imola.armbian.com/dl/" MULTITHREAD="20" IGNORE_HASH="yes" REPOSITORY_INSTALL="${REPOSITORY_INSTALL}" IGNORE_UPDATES="yes" REBUILD_IMAGES="${REBUILD_IMAGES}" KERNEL_ONLY="no" BETA="$BETA" BUILD_ALL="yes" MAKE_ALL_BETA="yes" USE_OVERLAYFS="yes"

exit

sleep 3m
while :
	do
        if [[ $(ps -uax | grep -E "compile|rsync" | wc -l) -lt 2 ]]; then
       	        break
        fi
       	sleep 60
done

# uploadaj
rsync -vr ${BLTPATH}output/images/. igorp@nas:/tank/armbian/dl.armbian.com

# recreate index
ssh igorp@utils "run-one /ext/scripts/recreate.sh"
