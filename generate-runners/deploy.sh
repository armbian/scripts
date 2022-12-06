#!/bin/bash
#
# This snippet will install as many Github runners you want
#
# PAT = personal access token (generate at your account, settings -> developers settings -> PAT)
# START = define start number, 0001, 0002, ... 01,02
# STOP  = define stop number
# NAME = name / keyword of this runner group


PAT=ghp_**********************************
START=005
STOP=006
NAME=qemu

# don't edit below
# -------------------------------------------------------------

# download runner app
sudo apt-get -y install libxml2-utils
LATEST=$(curl -sL https://github.com/actions/runner/releases/ | xmllint -html -xpath '//a[contains(@href, "release")]/text()' - 2> /dev/null | grep -P '^v' | head -n1 | sed "s/v//g")
curl --create-dir --output-dir .tmp -o actions-runner-linux-x64-${LATEST}.tar.gz -L https://github.com/actions/runner/releases/download/v${LATEST}/actions-runner-linux-x64-${LATEST}.tar.gz

for i in $(seq -w $START $STOP)
do
	TOKEN=$(curl -s \
	  -X POST \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer $PAT"\
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/orgs/armbian/actions/runners/registration-token | jq -r .token)

	mkdir -p actions-runner-${i}
	tar xzf .tmp/actions-runner-linux-x64-${LATEST}.tar.gz -C actions-runner-${i}
	sh -c "cd actions-runner-${i} ; ./config.sh --url https://github.com/armbian --token ${TOKEN} --labels qemu,cache --name $NAME-${i} --unattended"
	sh -c "cd actions-runner-${i} ; sudo ./svc.sh install ; sudo ./svc.sh start"
done
rm -rf .tmp
