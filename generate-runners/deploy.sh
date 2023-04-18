#!/bin/bash
#
# This snippet will install as many Github runners you want
#
# PAT = personal access token (generate at your account, settings -> developers settings -> PAT)
# START = define start number, 0001, 0002, ... 01,02
# STOP  = define stop number
# NAME = name / keyword of this runner group


#PAT=
START=001
STOP=002
NAME=runner
LABEL=big,test,arm64
ORG=armbian

# don't edit below
# -------------------------------------------------------------

# download runner app
sudo apt-get update
sudo apt-get -y install libxml2-utils jq docker.io
LATEST=$(curl -sL https://github.com/actions/runner/releases/ | xmllint -html -xpath '//a[contains(@href, "release")]/text()' - 2> /dev/null | grep -P '^v' | head -n1 | sed "s/v//g")
[[ "$(dpkg --print-architecture)" == "amd64" ]] && ARCH=x64 || ARCH=arm64
curl --create-dir --output-dir .tmp -o actions-runner-linux-${ARCH}-${LATEST}.tar.gz -L https://github.com/actions/runner/releases/download/v${LATEST}/actions-runner-linux-${ARCH}-${LATEST}.tar.gz

for i in $(seq -w $START $STOP)
do
	TOKEN=$(curl -s \
	  -X POST \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer $PAT"\
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/orgs/${ORG}/actions/runners/registration-token | jq -r .token)

	sudo userdel -r -f actions-runner-${i}
	sudo groupdel actions-runner-${i}
	sudo adduser --quiet --disabled-password --shell /bin/bash --home /home/actions-runner-${i} --gecos "actions-runner-${i}" actions-runner-${i}
	echo "actions-runner-${i} ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/actions-runner-${i}.conf
	sudo usermod -aG docker actions-runner-${i}
	sudo tar xzf .tmp/actions-runner-linux-${ARCH}-${LATEST}.tar.gz -C /home/actions-runner-${i}
	sudo chown -R actions-runner-${i}.actions-runner-${i} /home/actions-runner-${i}
	sudo runuser -l actions-runner-${i} -c "./config.sh --url https://github.com/${ORG} --token ${TOKEN} --labels ${LABEL} --name $NAME-${i} --unattended"
	sh -c "cd /home/actions-runner-${i} ; sudo ./svc.sh install actions-runner-${i}; sudo ./svc.sh start actions-runner-${i}"
done
rm -rf .tmp
