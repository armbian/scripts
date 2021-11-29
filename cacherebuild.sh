#!/bin/bash

BLTPATH="$(pwd)/"                               # path of the build script
FORCE=yes                                       # yes | force = remove cache and create new one
FORCED_MONTH_OFFSET=0                           # cache is valid one month. This allows creation in advance
MAKEFORALLAPPS="no"                             # yes = make all app combinations. It might be too much. If not set, hardcoded values are choosen
PARALLEL_BUILDS=""                              # choose how many you want to run in parallel. Leave empty for auto
USE_SCREEN="no"                                 # run commands in screen
FORCE_RELEASE="hirsute jammy bullseye"          # we only build supported releases caches. her you can add unsupported ones which you wish to experiment
FORCE_DESKTOP="cinnamon"                        # we only build supported desktop caches. here you can add unsupported ones which you wish to build anyway
PURGEDAYS="4"                                   # delete files that are older then n days and are not used anymore
CLEANING="${1:-no}"
FILE_OUT="${2:-filelist.txt}"
BUILD_VARIANTS="${1:-lepotato bananapi}"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


# load functions
source "$SCRIPT_DIR/cacherebuild-functions.sh"


# Main

# load config file to override default values
[[ -f cacherebuild.conf ]] && source "$SCRIPT_DIR/cacherebuild.conf" || display_alert "Using defaults" "" "info"

# hardcoded variables and calculations
DAYSBEFORE=4
START_TIME=$(date +%s)
MONTH=$(date -d "$M" '+%m' | sed 's/\<0//g')
DAYINMONTH=$(date -d "$D" '+%d' | sed 's/\<0//g')
REBUILDDAY=$(date -d "${MONTH}/1 + 1 month - ${DAYSBEFORE} day" "+%d")
MEM_INFO=$(($(LC_ALL=C free -w 2>/dev/null | grep "^Mem" | awk '{print $2}' || LC_ALL=C free | grep "^Mem"| awk '{print $2}')/1024))
r=0

# jump to build script folder
cd ${BLTPATH}

display_alert "Starting rootfs cache rebuilt" "$(date)" "info"
display_alert "Currently present cache files" "$(ls -l ${BLTPATH}cache/rootfs/*.lz4 2> /dev/null | wc -l)" "info"

# Update script just in case
git pull -q 2> /dev/null
if [[ $? -ne 0 ]]; then
    display_alert "Updating build script" "git pull" "err"
    exit 1
else
    display_alert "Updating build script" "git pull" "info"
fi

# Calculate parallel build tasks
display_alert "System memory" "$(($MEM_INFO/1024))Gb" "info"
if [[ -z ${PARALLEL_BUILDS} ]]; then
    PARALLEL_BUILDS=$(awk '{printf("%d",$1/12000)}' <<<${MEM_INFO})
    display_alert "Calculated parallel builds" "$PARALLEL_BUILDS" "info"
else
    display_alert "Selected parallel builds" "$PARALLEL_BUILDS" "info"
fi

# Rebuild or update
if [[ "${FORCE}" == "force" ]]; then
    display_alert "Cache will be removed and rebuild" "" "info"
else
    display_alert "Cache will be updated" "" "info"
fi

# when we should start building for next month
if [[ $DAYINMONTH -gt $REBUILDDAY ]]; then
    display_alert "${DAYSBEFORE} days before next month" "building for next month FORCED_MONTH_OFFSET=1" "info"
    FORCED_MONTH_OFFSET=1
fi

# first week we clean older files then 14 days
if [[ $DAYINMONTH -lt 7 ]]; then
    display_alert "First seven (7) days we clean files of previous month" "cleaning files older then 14 days" "info"
    find ${BLTPATH}cache/rootfs/ -type f -mtime +14 -exec sudo rm -f {} \;
fi

# don't start if previous run is still running
while :
do
    sleep 3
    CURRENT_TIME=$(date +%s)
	display_alert "Waiting for cleanup" "yes" "info"

    if [[ $(df | grep /.tmp | wc -l) -lt 1 ]]; then
        break
    fi
done

# removing previous cache if forced
[[ "${FORCE}" == "force" ]] && sudo rm -f ${BLTPATH}cache/rootfs/*

# run main rebuild function
releases

#
# wait until all build PIDS are done
#
while true
do
i=0
        for pids in $PIDS
        do
                if ps -p $pids > /dev/null; then
                        i=$((i+1))
                fi
        done

        [[ $i -eq 0 ]] && break

done



#
# clean all build that are not labelled as .current and are older then 4 days
#
if [[ "${FORCED_MONTH_OFFSET}" -eq 0 && "${CLEANING}" == "yes" ]]; then

	display_alert "Clean all build that are not labelled as current." "cleanup" "info"

        # create a diff between marked as current and others
        BRISI=($(diff <(find ${BLTPATH}cache/rootfs -name "*.lz4.current" | sed "s/.current//" | sort) <(find ${BLTPATH}cache/rootfs -name "*.lz4" | sort) | grep ">" | sed "s/> //"))
        for brisi in "${BRISI[@]}"; do
            if [[ $(find "$brisi" -mtime +${PURGEDAYS} -print) ]]; then
                    display_alert "File is older then ${PURGEDAYS} days. Deleting." "$(basename $brisi)" "info"
                    sudo rm $brisi
                else
                    display_alert "File is not older then ${PURGEDAYS} days" "$(basename $brisi)" "info"
            fi
        done

        # remove .current mark
        sudo rm -f ${BLTPATH}cache/rootfs/*.current
fi



# calculate execution time
display_alert "Currently present cache files" "$(ls -l ${BLTPATH}cache/rootfs/*.lz4 2> /dev/null| wc -l)" "info"

# removing previous tmp build directories
sudo rm -rf ${BLTPATH}.tmp
