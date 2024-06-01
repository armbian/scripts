#!/bin/bash
#
# This snippet will install as many Github runners you want
#
# PAT = personal access token (generate at your account, settings -> developers settings -> PAT)
# START = define start number, 0001, 0002, ... 01,02
# STOP  = define stop number
# NAME = name / keyword of this runner group


#GH_TOKEN=
START=1
#STOP=02
#NAME=temporally
LABEL_PRIMARY="alfa,beta,gama,temp"
LABEL_SECONDARY="fast,images,temp"
#ORG=armbian
OWNER=armbian
REPO=os

# don't edit below
# -------------------------------------------------------------

runner_delete ()
{
	DELETE=$1

	x=1
	while [ $x -le 9 ] # need to do it different as it can be more then 9 pages
	do
	RUNNER=$(
	curl -s -L \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer ${GH_TOKEN}" \
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/orgs/armbian/actions/runners\?page\=${x} \
	| jq -r '.runners[] | .id, .name' | xargs -n2 -d'\n' | sed -e 's/ /,/g')

	while IFS= read -r DATA; do
		RUNNER_ID=$(echo $DATA | cut -d"," -f1)
		RUNNER_NAME=$(echo $DATA | cut -d"," -f2)
		# deleting a runner
		if [[ $RUNNER_NAME == ${DELETE} ]]; then
			echo "Delete existing: $RUNNER_NAME"
			curl -s -L \
			-X DELETE \
			-H "Accept: application/vnd.github+json" \
			-H "Authorization: Bearer ${GH_TOKEN}"\
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/orgs/${ORG}/actions/runners/${RUNNER_ID}
		fi

	done <<< $RUNNER
	x=$(( $x + 1 ))
	done
}

# we can generate per org or per repo
REGISTRATION_URL="${ORG}"
PREFIX="orgs"
if [[ -n "${OWNER}" && -n "${REPO}" ]]; then
    REGISTRATION_URL="${OWNER}/${REPO}"
    PREFIX=repos
fi

# update OS and install dependencies
sudo apt-get -q update
[[ -z $(command -v xmllint) ]] && sudo apt-get -yy install libxml2-utils
[[ -z $(command -v jq) ]] && sudo apt-get -yy install jq
[[ -z $(command -v curl) ]] && sudo apt-get -yy install curl
[[ -z $(command -v docker) ]] && sudo apt-get -yy install docker.io

# download latest runner
LATEST=$(curl -sL https://github.com/actions/runner/releases/ | xmllint -html -xpath '//a[contains(@href, "release")]/text()' - 2> /dev/null | grep -P '^v' | head -n1 | sed "s/v//g")
[[ "$(dpkg --print-architecture)" == "amd64" ]] && ARCH=x64 || ARCH=arm64
curl --create-dir --output-dir .tmp -o actions-runner-linux-${ARCH}-${LATEST}.tar.gz -L https://github.com/actions/runner/releases/download/v${LATEST}/actions-runner-linux-${ARCH}-${LATEST}.tar.gz

# make runners each under its own user
for i in $(seq -w $START $STOP)
do

	TOKEN=$(curl -s \
	  -X POST \
	  -H "Accept: application/vnd.github+json" \
	  -H "Authorization: Bearer $GH_TOKEN"\
	  -H "X-GitHub-Api-Version: 2022-11-28" \
	  https://api.github.com/${PREFIX}/${REGISTRATION_URL}/actions/runners/registration-token | jq -r .token)

	if id "actions-runner-${i}" >/dev/null 2>&1; then
		runner_delete "$NAME-${i}"
		runner_home=$(getent passwd "actions-runner-${i}" | cut -d: -f6)
		sh -c "cd ${runner_home} ; sudo ./svc.sh stop actions-runner-${i} >/dev/null; sudo ./svc.sh uninstall actions-runner-${i} >/dev/null"
		sudo userdel -r -f actions-runner-${i} 2>/dev/null
		sudo groupdel actions-runner-${i} 2>/dev/null
		sudo rm -rf "${runner_home}"
	fi

	sudo adduser --quiet --disabled-password --shell /bin/bash --home /home/actions-runner-${i} --gecos "actions-runner-${i}" actions-runner-${i}
	# add to sudoers
	if ! sudo grep -q "actions-runner-${i}" /etc/sudoers; then
            echo "actions-runner-${i} ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
        fi
	sudo usermod -aG docker actions-runner-${i}
	sudo tar xzf .tmp/actions-runner-linux-${ARCH}-${LATEST}.tar.gz -C /home/actions-runner-${i}
	sudo chown -R actions-runner-${i}:actions-runner-${i} /home/actions-runner-${i}

        # 1st runner has different labels
        LABEL=$LABEL_SECONDARY
        if [[ "$i" == "${START}" ]]; then
	LABEL=$LABEL_PRIMARY
	fi

	sudo runuser -l actions-runner-${i} -c "./config.sh --url https://github.com/${REGISTRATION_URL} --token ${TOKEN} --labels ${LABEL} --name $NAME-${i} --unattended"
	sh -c "cd /home/actions-runner-${i} ; sudo ./svc.sh install actions-runner-${i} 2>/dev/null; sudo ./svc.sh start actions-runner-${i} >/dev/null"
done
rm -rf .tmp
