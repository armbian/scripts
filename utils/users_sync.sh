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
USERPATH=/var/www/users

# which group is used to catch and jail users into their sftp chroot?
SFTPGROUP=sftponly

# classic token from any organization member with "read:org" permission
TOKEN=xxxxxx

# the organization you want to read members from
ORG=armbian

# Users that shall not get access
BLOCKLIST='armbianworker|examplemember1|examplemember2'
### END CONFIG


### DO NOT EDIT BELOW! ###


### CHECKS
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
    echo "    ChrootDirectory $USERPATH/%u"
    echo "    ForceCommand internal-sftp"
    echo "    AllowTcpForwarding no"
    echo ""
    echo "Exiting..."
    exit 1
fi
### END CHECKS


# grab a list of current remote org members, filter blocked ones
echo "Grabbing a list of all current members of \"$ORG\"."
echo "Excluded by blocklist are \"$BLOCKLIST\"."
ORGMEMBERS=$(curl -L -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/$ORG/members | jq -r ".[].login" \
  | grep -v -E -- "$BLOCKLIST" )

# Grab a list of local directories...
# We assume that existing directory means locally existing user as well
cd $USERPATH || exit 1
LOCALMEMBERS=$(echo -n "`ls -d -- */`" | sed 's/\///g' | tr '\n' ' ')
echo "Already existing members at \"$USERPATH\": \"$LOCALMEMBERS\"."
# ...and make it comparable for shell (remove trailing slash, replace newline with | and add round brackets)
LOCALMEMBERS_COMPARE=$(echo -n "`ls -d -- */`" | sed 's/\///g' | tr '\n' '|' | sed -r 's/^/\(/' | sed -r 's/$/\)/')


# loop through remote org members and add if not existing
for i in $ORGMEMBERS; do

    if ! [[ $i =~ $LOCALMEMBERS_COMPARE ]]; then # skip locally already existing users

        # create local user and directory
        echo "$i - no local directory found. Creating..."
        if ! useradd -m -s /bin/bash -G "$SFTPGROUP" -d "$USERPATH"/"$i" "$i"
        then
            echo "$i's directory could not be created for whatever reason"
            exit 1
        fi
        echo "$i directory created"

        # grab ssh keys and put into user's .ssh/authorized_keys file
        echo "Trying to grab ssh keys"
        mkdir -p "$USERPATH"/"$i"/.ssh
        curl -s https://github.com/"$i".keys > "$USERPATH"/"$i"/.ssh/authorized_keys
        chown -R "$i":"$SFTPGROUP" "$USERPATH"/"$i"/.ssh
        chmod 600 "$USERPATH"/"$i"/.ssh/authorized_keys

        # Check if grabbed stuff are actual ssh keys.
        # curl response for members w/o keys is "not found" but exit code is still 0
        # so this needs to be worked around
        CHECK_KEYS=$(grep -c -E "^ssh" "$USERPATH"/"$i"/.ssh/authorized_keys)
        if [[ $CHECK_KEYS != 0 ]]; then
            echo "$i - $CHECK_KEYS key/s for $i imported"
        else
            echo "$i - Either grabbing failed or $i does not have ssh key on git"
            echo "$i won't be able to login"
            rm "$USERPATH"/"$i"/.ssh/authorized_keys
        fi

    else
        echo "$i - local directory found. Skipping..."
        # TODO: update ssh keys here
    fi
done

# remove local users not exsting in remote org
ORGMEMBERS_COMPARE=$(echo -n "`curl -L -s \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/orgs/$ORG/members | jq -r ".[].login"`" \
  | sed 's/\ /|/g' | sed -r 's/^/\(/' | sed -r 's/$/\)/')

for i in $LOCALMEMBERS; do

    if ! [[ $i =~ $ORGMEMBERS_COMPARE ]]; then # compare local user against list of remote org members. If not found carry on
        echo "$i is not or no longer in the list of remote org members. Removing its legacy..."
        userdel --remove "$i"
    else
        echo "$i is still member of remote org. Skipping..."
    fi
done
