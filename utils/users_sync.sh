#!/bin/bash


### TODO
# add blocklist/keeplist
# add update/refresh keys on existing user
# make sure concealed members are grabbed as well: https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#list-organization-members


### CONFIG
# where are the user directories?
# NO trailing slash!
# the owner of the parent directory must be "root"!
# configure nginx accordingly
USERPATH=/armbianusers

# which group is used to catch and jail users into their sftp chroot?
SFTPGROUP=sftponly

# classic token from any organization member with "read:org" permission
TOKEN=xxx

# the organization you want to read members from
ORG=armbian

# Users that shall not get access
BLOCKLIST='armbianworker|examplemember1|examplemember2'
### END CONFIG


### DO NOT EDIT BELOW! ###


### CHECKS
# Check if curl is installed
command -v curl >/dev/null 2>&1 || echo >&2 "\"curl\" not found. Aborting."

# Check if jq is installed
command -v jq >/dev/null 2>&1 || echo >&2 "\"jq\" not found. Aborting."


# validate token
RESPONSE=$(curl -sS -f -I -H "Authorization: token $TOKEN" https://api.github.com | grep -i x-oauth-scopes |grep -c read:org)
if [[ $RESPONSE != 1 ]]; then
    echo "Token invalid or lacking permission."
    echo "Exiting..."
    exit 1
fi

# check for root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    echo "Exiting..."
    exit 1
fi

# check for existing sftp group
if ! getent group sftponly &> /dev/null
then
    echo "\"$SFTPGROUP\" group does not exist. Use \"groupadd $SFTPGROUP\" to add."
    echo ""
    echo "Add this to your \"sshd_config\" if not done already."
    echo ""
    echo "Match Group $SFTPGROUP"
    echo "    ChrootDirectory $USERPATH"
    echo "    ForceCommand internal-sftp"
    echo "    AllowTcpForwarding no"
    echo ""
    echo "Exiting..."
    exit 1
fi
### END CHECKS


### FUNCTIONS

grab_keys() {
# $1 = username
    echo "Trying to grab ssh keys for $1"
    mkdir -p "$USERPATH"/"$1"/.ssh
    curl -s https://github.com/"$1".keys > "$USERPATH"/"$1"/.ssh/authorized_keys
    chown -R "$1":"$SFTPGROUP" "$USERPATH"/"$1"/.ssh
    chmod 700 "$USERPATH"/"$1"/.ssh
    chmod 600 "$USERPATH"/"$1"/.ssh/authorized_keys

    # Check if grabbed stuff are actual ssh keys.
    # curl response for members w/o keys is "not found" but exit code is still 0
    # so this needs to be worked around
    CHECK_KEYS=$(grep -c -E "^ssh" "$USERPATH"/"$1"/.ssh/authorized_keys)
    if [[ $CHECK_KEYS != 0 ]]; then
        echo "$i - $CHECK_KEYS key/s for $1 imported"
    else
        echo "(!) $1 - Either grabbing failed or $i does not have ssh key on git"
        echo "(!) $1 won't be able to login"
        rm "$USERPATH"/"$1"/.ssh/authorized_keys
    fi
}


# grab a list of current remote org members, filter blocked ones
echo "Grabbing a list of all current members of \"$ORG\"."
echo "Excluded by blocklist are \"$BLOCKLIST\"."
ORGMEMBERS=$(curl -L -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/$ORG/members | jq -r ".[].login" \
  | grep -v -E -- "$BLOCKLIST" )
echo "DEBUG: \$ORGMEMBERS: $ORGMEMBERS"

# Grab a list of local directories...
# We assume that existing directory means locally existing user as well
cd $USERPATH || exit 1
LOCALMEMBERS=$(echo -n "`ls -d -- */`" | sed 's/\///g' | tr '\n' ' ')
echo "Already existing members at \"$USERPATH\": \"$LOCALMEMBERS\"."
# ...and make it comparable for shell (remove trailing slash, replace newline with | and add round brackets)
LOCALMEMBERS_COMPARE=$(echo -n "`ls -d -- */`" | sed 's/\///g' | tr '\n' '|' | sed -r 's/^/\(/' | sed -r 's/$/\)/')
echo "DEBUG: \$LOCALMEMBERS_COMPARE: $LOCALMEMBERS_COMPARE"

# loop through remote org members and add if not existing
for i in $ORGMEMBERS; do

    if ! [[ $i =~ $LOCALMEMBERS_COMPARE ]]; then # skip locally already existing users

        # create local user and directory
        echo "$i - no local directory found. Creating..."
        if ! useradd -m -s /bin/false -G "$SFTPGROUP" -d "$USERPATH"/"$i" "$i"
        then
            echo "$i's directory could not be created for whatever reason"
            exit 1
        fi
        echo "$i - user and directory created"

        # grab ssh keys and put into user's .ssh/authorized_keys file
        grab_keys "$i"

    else
        echo "$i - local directory found. Trying to update keys..."
        grab_keys "$i"

    fi
done

echo ""
echo "Removing no longer existing members"
echo ""
### remove local users not exsting in remote org
# make list of remote organization members comparable
ORGMEMBERS_COMPARE=$(echo "$ORGMEMBERS" | tr '\n' ' ' | sed 's/\ /\|/g'| sed -r 's/^/\(/' | sed -r 's/\|$/\)/')
echo "DEBUG: \$ORGMEMBERS_COMPARE: $ORGMEMBERS_COMPARE"
echo "DEBUG: \$LOCALMEMBERS: $LOCALMEMBERS"
# loop through org members and compare against local list
for i in $LOCALMEMBERS; do

    if [[ $i =~ $ORGMEMBERS_COMPARE ]]; then # compare local user against list of remote org members. If not found carry on
        echo "$i is still member of remote org. Skipping..."
    else
        echo "$i is not or no longer in the list of remote org members or has been blocklisted. Removing its legacy..."
        userdel --remove "$i"
    fi
done

