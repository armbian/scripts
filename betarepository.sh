#!/bin/bash

#BLTPATH="/build/"
PULL_FROM="master"

# load config file to override default values
[[ -f betarepository.conf ]] && source betarepository.conf

# delete lock file after 6  hours
sudo find /run -name nightly-repo -type f -mmin +1440 -delete

# exit if kernel update is running
[[ -f /var/run/nightly-repo ]] && echo "Previous job didn't finished." && exit 0
[[ -f ${BLTPATH}output/debs-beta/.waiting ]] && echo "Repository update in progress. Job will restart automatically!" && exit 0

# remove lock file on exit
trap '{ sudo rm -f -- "/var/run/nightly-repo"; }' EXIT
sudo sh -c 'echo $$ > /var/run/nightly-repo'

# remove user configs
sudo rm ${BLTPATH}userpatches/targets.conf 2>/dev/null

cd ${BLTPATH}

# refresh
sudo git pull
sudo git clean -f

# pull changes from master and push to nightly
CURRENT=`sudo git branch | grep "*" | awk '{print $2}'`

# exit if not on nightly
[[ "$CURRENT" != "nightly" ]] && exit 1

# pull from desktop
sudo git checkout -f $PULL_FROM
sudo git reset --hard origin/$PULL_FROM
sudo git fetch
sudo git merge origin/$PULL_FROM
sudo git checkout ${CURRENT}
sudo git merge $PULL_FROM ${CURRENT} --no-ff --no-edit

# exit if push to nightly is not possible
[[ $(sudo git branch | grep "*" | awk '{print $2}') != nightly ]] && exit 1
echo "1"
[[ $? -eq 0 ]] && sudo git push || exit 1

# Build kernels if there is any change to patches, config or upstream
#
# Add patches with label: "beta" or "need testings"
#
#for h in $(sudo gh pr list --label "8.beta" --label "7.needs testing" -R "https://github.com/armbian/build" | cut -f1 | xargs); do
#        KOMANDA="sudo wget -qO - https://github.com/armbian/build/pull/$h.patch | sudo git apply --whitespace=nowarn"
#        eval $KOMANDA
#done

./compile.sh all-new-beta-kernels

if [[ $? -ne 0 ]]; then
	# report error
	exit 1
elif [[ "$(cat .tmp/n 2> /dev/null)" -eq 0 ]]; then
	sudo rm -f /var/run/nightly-repo
	exit 0
fi

# exit if not changes
if [[ -n $(cat output/debug/output.log| grep Error) ]]; then
	echo "Error"
	# report for error
	exit 1
fi

# create BSP
./compile.sh all-new-beta-bsp
[[ $? -ne 0 ]] && exit 1

sleep 1m
touch output/debs-beta/.waiting
echo "Updating repository"
while :
do
	sleep 15m
	echo "."
	[[ ! -f output/debs-beta/.waiting ]] && break
done
./compile.sh all-new-beta-kernels BUMP_VERSION="yes"
