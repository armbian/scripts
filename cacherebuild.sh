#!/bin/bash

BLTPATH="$(pwd)/"                     # path of the build script
FORCE=yes                             # yes | force = remove cache and create new one
FORCED_MONTH_OFFSET=0                 # cache is valid one month. This allows creation in advance
MAKEFORALLAPPS="no"                   # yes = make all app combinations. It might be too much. If not set, hardcoded values are choosen
PARALLEL_BUILDS=12                    # choose how many you can run in parallel - depends on your hardware
USE_SCREEN="no"                       # run commands in screen
FORCE_RELEASE="hirsute bullseye"      # we only build supported releases caches. her you can add unsupported ones which you wish to experiment


# load config file to override default values
[[ -f cacherebuild.conf ]] && source cacherebuild.conf


# go to build script root and run update
cd ${BLTPATH}
git pull
TEMP_DIR=$(mktemp -d || exit 1)
r=0


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
        PARAMETER+=" DESKTOP_ENVIRONMENT_CONFIG_NAME=\"$4\" DESKTOP_APPGROUPS_SELECTED=\"$5\" "
        PARAMETER+=" ROOT_FS_CREATE_ONLY=\"${FORCE}\" KERNEL_ONLY=\"no\" KERNEL_CONFIGURE=\"no\" FORCED_MONTH_OFFSET=\"${FORCED_MONTH_OFFSET}\""
        PARAMETER+=" IGNORE_UPDATES=\"yes\" SYNC_CLOCK=\"no\" REPOSITORY_INSTALL=\"u-boot,kernel,bsp,armbian-config,armbian-firmware\" EXPERT=\"yes\""

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
        echo "$1-$vari">> $TEMP_DIR/in.txt
        while :
        do
            sleep 1.2
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
#   Cycle or scan for releases we use
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
#   Cycle build variants, cli, cli, minimal
#
function variants
{

    local variants=(cli_1 cli_2)
    if [[ -d config/desktop ]]; then
        local variants+=($(find -L config/desktop/$1/environments/ -name support -exec grep -l 'supported' {} \; | cut -d"/" -f5))
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
        boards "$1" "$2" "$3" "$4" "3dsupport browsers chat desktop_tools editors email internet languages multimedia office programming remote_desktop"
    else
        boards "$1" "$2" "$3" "$4" ""
    fi

}


START_TIME=$(date +%s)
MEM_INFO=$(LC_ALL=C free -w 2>/dev/null | grep "^Mem" || LC_ALL=C free | grep "^Mem")
PARALLEL=$(awk '{printf("%d",$2/1024/1800)}' <<<${MEM_INFO})

# check if we need to do this at all
rootfsver=$(cat ${BLTPATH}lib/configuration.sh | grep ROOTFSCACHE_VERSION)
eval $roofsver
# making cache for next month +1
gethash=$(echo "$(date -d "$D +${FORCED_MONTH_OFFSET} month" +"%Y-%m-module$ROOTFSCACHE_VERSION" | sed 's/^0*//')" | git hash-object --stdin )
cachefile=${BLTPATH}cache/hash/rootfs.githash

[[ -f $cachefile ]] && readhash=$(cat ${BLTPATH}cache/hash/rootfs.githash)
if [[ "$readhash" == "$gethash" ]]; then

    echo "No need to rebuild"

else

    #echo "Rebuilding cache"
    # clean old cache just to make sure
    [[ "${FORCE}" == "force" ]] && sudo rm -f ${BLTPATH}cache/rootfs/*
    sudo rm -rf ${BLTPATH}.tmp

    # run rebuild
    releases

    # wait until
    sleep 3
    while :
        do
        sleep 3
        CURRENT_TIME=$(date +%s)
        echo -ne "Rebuilding cache: \x1B[92m$(( CURRENT_TIME - START_TIME ))s\x1B[0m\r"
        if [[ $(df | grep /.tmp | wc -l) -lt 1 ]]; then
            break
        fi
    done

    #diff=$(comm -3 <(ls -1 ${BLTPATH}cache/rootfs/*.lz4 | sed -r "s/.+\/(.+)\..+/\1/" | sed "s/-arm.*//" | sort) <(sort $TEMP_DIR/in.txt) | xargs)
    #[[ -n $diff ]] && echo -e "Subject: Problem with cache rebuild\n\n$diff was not finished"
    #| ssmtp igor@armbian.com

    [[ $UPLOAD != "yes" ]] && exit

    rsync -arP --info=progress2 --info=name0 ${BLTPATH}cache/rootfs/. igorp@10.0.10.2:/tank/armbian/dl.armbian.com/_rootfs

    # fix permissions
    ssh igorp@10.0.10.2 "sudo chown -R igorp.sudo /tank/armbian/dl.armbian.com"

    while :
    do
        ssh igorp@10.0.10.52 "run-one sudo /root/sync-images-to-minio"
        [[ $? -eq 0 ]] && break
        sleep 5
    done

    # create torrents
    ssh igorp@10.0.10.10 "run-one /ext/scripts/recreate.sh"

    # wait a day that mirrors are synched
    echo "Sleeping"
    sleep 24h

    echo "Synching"
    rsync -arP --delete --info=progress2 --info=name0 ${BLTPATH}cache/rootfs/. igorp@10.0.10.2:/tank/armbian/dl.armbian.com/_rootfs
    # create torrents to remove deprecated
    ssh igorp@10.0.10.10 "run-one /ext/scripts/recreate.sh"

    # store hash
    echo ${gethash} > ${cachefile}

fi