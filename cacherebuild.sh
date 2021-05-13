#!/bin/bash

BLTPATH="$(pwd)/"                               # path of the build script
FORCE=yes                                       # yes | force = remove cache and create new one
FORCED_MONTH_OFFSET=0                           # cache is valid one month. This allows creation in advance
MAKEFORALLAPPS="no"                             # yes = make all app combinations. It might be too much. If not set, hardcoded values are choosen
PARALLEL_BUILDS=""                              # choose how many you want to run in parallel. Leave empty for auto
USE_SCREEN="no"                                 # run commands in screen
FORCE_RELEASE="hirsute bullseye"                # we only build supported releases caches. her you can add unsupported ones which you wish to experiment
FORCE_DESKTOP="deepin cinnamon i3-wm xmonad"    # we only build supported desktop caches. here you can add unsupported ones which you wish to build anyway
PURGEDAYS="3"                                   # delete files that are older then n days and are not used anymore




#
# Fancy status display
#
display_alert()
{

    local tmp=""
    [[ -n $2 ]] && tmp="[\e[0;33m $2 \x1B[0m]"

    case $3 in

        err)
        echo -e "[\e[0;31m error \x1B[0m] $1 $tmp"
        ;;

        wrn)
        echo -e "[\e[0;35m warn \x1B[0m] $1 $tmp"
        ;;

        ext)
        echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m $tmp"
        ;;

        info)
        echo -e "[\e[0;32m o.k. \x1B[0m] $1 $tmp"
        ;;

        *)
        echo -e "[\e[0;32m .... \x1B[0m] $1 $tmp"
        ;;

    esac

}




#
# Cycle main build commands
#
function boards
{

    # we only need to select one 32 and one 64bit board
    local TARGETS=(lepotato bananapi)
    for h in "${TARGETS[@]}"
    do

        PARAMETER=""

        [[ $PARALLEL -gt 1 && $USE_SCREEN == yes ]] && PARAMETER="screen -dmSL ${h}$1 "

        PARAMETER+="${BLTPATH}compile.sh BOARD=\"$h\" BRANCH=\"current\" RELEASE=\"$1\""
        if [[ $2 == cli* ]]; then

            PARAMETER+=" BUILD_MINIMAL=\"$4\" BUILD_DESKTOP=\"no\" DESKTOP_ENVIRONMENT=\"\""

            else

            PARAMETER+=" BUILD_MINIMAL=\"no\" BUILD_DESKTOP=\"yes\" DESKTOP_ENVIRONMENT=\"$2\""

        fi

        PARAMETER+=" DESKTOP_ENVIRONMENT_CONFIG_NAME=\"$4\" DESKTOP_APPGROUPS_SELECTED=\"$5\" ROOT_FS_CREATE_ONLY=\"${FORCE}\" KERNEL_ONLY=\"no\" "
        PARAMETER+=" KERNEL_CONFIGURE=\"no\" OFFLINE_WORK=\"yes\" FORCED_MONTH_OFFSET=\"${FORCED_MONTH_OFFSET}\" IGNORE_UPDATES=\"yes\" SYNC_CLOCK=\"no\" ARMBIAN_MIRROR=\"https://imola.armbian.com/dl/\" "
        PARAMETER+=" REPOSITORY_INSTALL=\"u-boot,kernel,bsp,armbian-config,armbian-firmware\" EXPERT=\"yes\" USE_TORRENT=\"no\" APT_PROXY_ADDR=\"10.0.10.10:3142\""

        [[ $USE_SCREEN != yes ]] && PARAMETER+=" &"

        r=$(( r + 1 ))
        vari=$2

        # support for older way. will be deprecated once merged
        [[ ! -d config/desktop && $2 == cli_1 ]] && vari=cli
        [[ ! -d config/desktop && $2 == cli_2 ]] && vari=minimal
        [[ ! -d config/desktop && $2 == xfce ]] && vari=xfce-desktop

        CURRENT_TIME=$(date +%s)

        [[ $h == "lepotato" ]] && build_architec="arm64" || build_architec="armhf"

        if [[ ${DISPLAY_STAT} == yes ]]; then
            echo "Rebuilding cache: $(( CURRENT_TIME - START_TIME ))"
            echo "[ ${r}. $1_${build_architec}_$2" "$3" "$4" "$5 ]"
            echo ""
        fi

        eval "$PARAMETER"

	# store pids
	PIDS=$PIDS" "$(echo $!)

        while :
        do
            sleep 0.5
            CURRENT_TIME=$(date +%s)
            CONCURENT=$(df | grep /.tmp | wc -l)
            FREE_MEM=$(free | grep Mem | awk '{print $4/$2 * 100}' | awk '{print int($1+0.5)}')

            if [[ ${CONCURENT} -le ${PARALLEL_BUILDS} ]]; then
                break
            fi

        done

    done

}




#
# Cycle or scan for releases we use
#
function releases
{

    if [[ -d config/desktop ]]; then

        local releases=($(grep -rw config/distributions/* -e 'supported' | cut -d"/" -f3))        
        [[ -n $FORCE_RELEASE ]] && local releases+=($FORCE_RELEASE)

    else

        local releases=(bionic focal bullseye groovy buster stretch xenial)

    fi

    for i in ${releases[@]}
    do

        variants "$i"

    done

}




#
# Cycle build variants, cli, cli, minimal
#
function variants
{

    local variants=(cli_1 cli_2)
    if [[ -d config/desktop ]]; then

        local variants+=($(find -L config/desktop/$1/environments/ -name support -exec grep -l 'supported' {} \; | cut -d"/" -f5))
        [[ -n $FORCE_DESKTOP ]] && local variants+=($FORCE_DESKTOP)

    else

        local variants+=(xfce)

    fi
    for j in ${variants[@]}
    do

        build_desktop="yes"
        build_minimal="no"
        [[ $j == cli_1 ]] && build_desktop="no" && build_minimal="no"
        [[ $j == cli_2 ]] && build_desktop="no" && build_minimal="yes"
        configs "$1" "$j" "$build_desktop" "$build_minimal"

    done

}




#
#   Cycle build configs - full / minimal / medium
#
function configs
{

    if [[ -d config/desktop && $build_desktop != no ]]; then

        local configs=($(find -L config/desktop/$1/environments/$2/config* -name packages 2>/dev/null | cut -d"/" -f6 | uniq))

    else

        local configs="$4"

    fi

    for k in ${configs[@]}
    do

        appgroup "$1" "$2" "$3" "$k"

    done

}




#
#   Cycle appgroup and make all combinations
#
function appgroup
{

    # optionally set limi from head. Default = all
    local limit=16

    if [[ -d config/desktop && $3 == "yes" && $MAKEFORALLAPPS == "yes" ]]; then

        string=$(find -L config/desktop/$1/appgroups/ -mindepth 1 -maxdepth 1 -type d 2> /dev/null | sort | cut -d"/" -f5 | head -${limit} | tr '\n' ' ' )
        string=$(printf '%s\n' "$string" | tr -s '[:blank:]' ' ')
        wordCount=$(printf '%s\n' "$string" | wc -w)
        start=1
        boards "$1" "$2" "$3" "$4" ""
        while [ $start -le $wordCount ]; do

            end=$start
            while [ $end -le $wordCount ]; do

                boards "$1" "$2" "$3" "$4" "$(printf '%s\n' "$string" | cut -d ' ' -f "$start-$end")"
                end=$(( end + 1 ))

            done
            start=$(( start + 1 ))

        done

    elif [[ -d config/desktop && $3 == "yes" ]]; then

        boards "$1" "$2" "$3" "$4" ""
        boards "$1" "$2" "$3" "$4" "browsers"
        boards "$1" "$2" "$3" "$4" "browsers chat desktop_tools editors email internet languages multimedia office programming remote_desktop"
        boards "$1" "$2" "$3" "$4" "3dsupport browsers chat desktop_tools editors email internet languages multimedia office programming remote_desktop"

    else

        boards "$1" "$2" "$3" "$4" ""

    fi

}




#
# Main function
#

# load config file to override default values
[[ -f cacherebuild.conf ]] && source cacherebuild.conf

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

git pull -q 2> /dev/null

if [[ $? -ne 0 ]]; then

    display_alert "Updating build script" "git pull" "err"
    exit 1

else

    display_alert "Updating build script" "git pull" "info"

fi


display_alert "System memory" "$(($MEM_INFO/1024))Gb" "info"


if [[ -z ${PARALLEL_BUILDS} ]]; then

    PARALLEL_BUILDS=$(awk '{printf("%d",$1/5000)}' <<<${MEM_INFO})
    display_alert "Calculated parallel builds" "$PARALLEL_BUILDS" "info"

else

    display_alert "Selected parallel builds" "$PARALLEL_BUILDS" "info"

fi


if [[ "${FORCE}" == "force" ]]; then

    display_alert "Cache will be removed and rebuild" "${FORCE}" "info"

else

    display_alert "Cache will be updated" "${FORCE}" "info"

fi

# when we should start building for next month
if [[ $DAYINMONTH -gt $REBUILDDAY ]]; then

    display_alert "${DAYSBEFORE} days before next month" "building for next month FORCED_MONTH_OFFSET=1" "info"
    FORCED_MONTH_OFFSET=1

fi

if [[ $DAYINMONTH -lt 7 ]]; then

    display_alert "First seven (7) days we clean files of previous month" "cleaning files older then 14 days" "info"
    find ${BLTPATH}cache/rootfs/ -type f -mtime +14 -exec sudo rm -f {} \;

fi

if [[ $UPLOAD != "yes" ]]; then

    display_alert "Uploading to servers" "no" "info"

else

    display_alert "Uploading to servers" "yes" "info"

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

# removing previous tmp build directories
sudo rm -rf ${BLTPATH}.tmp
sudo rm ${BLTPATH}cache/rootfs/*.current 2>/dev/null

if [[ -f ${BLTPATH}cache/rootfs/.waiting ]]; then
	display_alert "Syncing in progress. Exiting." "cache/rootfs/.waiting exits" "info"
	exit 0
fi

sleep 3

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
if [[ ${FORCED_MONTH_OFFSET} -eq 0 ]]; then

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
	sudo rm ${BLTPATH}cache/rootfs/*.current
fi

# calculate execution time
CURRENT_TIME=$(date +%s)
display_alert "Rebuilding cache time" "$(( CURRENT_TIME - START_TIME )) seconds" "info"
display_alert "Currently present cache files" "$(ls -l ${BLTPATH}cache/rootfs/*.lz4 | wc -l)" "info"

# files are collected by 3rd party script if this file exists
touch ${BLTPATH}cache/rootfs/.waiting
