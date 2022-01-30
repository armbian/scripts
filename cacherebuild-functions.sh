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
    local TARGETS=($BUILD_VARIANTS)
    #local TARGETS=(lepotato bananapi)
    for h in "${TARGETS[@]}"
    do

        PARAMETER=""

        [[ $PARALLEL_BUILDS -gt 1 && $USE_SCREEN == yes ]] && PARAMETER="screen -dmSL ${h}$1 "

        PARAMETER+="${BLTPATH}compile.sh BOARD=\"$h\" BRANCH=\"current\" RELEASE=\"$1\""
        if [[ $2 == cli* ]]; then

            PARAMETER+=" BUILD_MINIMAL=\"$4\" BUILD_DESKTOP=\"no\" DESKTOP_ENVIRONMENT=\"\""

            else

            PARAMETER+=" BUILD_MINIMAL=\"no\" BUILD_DESKTOP=\"yes\" DESKTOP_ENVIRONMENT=\"$2\""

        fi

        PARAMETER+=" DESKTOP_ENVIRONMENT_CONFIG_NAME=\"$4\" DESKTOP_APPGROUPS_SELECTED=\"$5\" ROOT_FS_CREATE_ONLY=\"${FORCE}\" KERNEL_ONLY=\"no\" BETA=\"yes\" "
        PARAMETER+=" KERNEL_CONFIGURE=\"no\" OFFLINE_WORK=\"yes\" FORCED_MONTH_OFFSET=\"${FORCED_MONTH_OFFSET}\" IGNORE_UPDATES=\"yes\" SYNC_CLOCK=\"no\"  "
        PARAMETER+=" NO_HOST_RELEASE_CHECK=\"yes\" REPOSITORY_INSTALL=\"u-boot,kernel,bsp,armbian-config,armbian-firmware\" EXPERT=\"yes\" USE_TORRENT=\"no\" CUSTOM_UBUNTU_MIRROR=\"si.archive.ubuntu.com/ubuntu\""

##        [[ $USE_SCREEN != yes ]] && PARAMETER+=" &"

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

	if [[ "$CLEANING" != "yes" ]]; then
            echo "$PARAMETER" >> "$FILE_OUT"
	else
            eval "$PARAMETER"	        
	fi

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

	local releases=($(grep -rw config/distributions/*/ -e 'supported' | cut -d"/" -f3))
	[[ -n $FORCE_RELEASE ]] && local releases+=($FORCE_RELEASE)

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
    local variants+=($(find -L config/desktop/$1/environments/ -name support -exec grep -l 'supported' {} \; | cut -d"/" -f5))
    [[ -n $FORCE_DESKTOP ]] && local variants+=($FORCE_DESKTOP)

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

	if [[ -d "config/desktop/$1/appgroups/3dsupport" ]]; then
		boards "$1" "$2" "$3" "$4" "3dsupport browsers"
		boards "$1" "$2" "$3" "$4" "3dsupport browsers chat desktop_tools editors email internet languages multimedia office programming remote_desktop"
	fi

    else

        boards "$1" "$2" "$3" "$4" ""

    fi

}
