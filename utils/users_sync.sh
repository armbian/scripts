#!/bin/bash


### CONFIG
# where are the user directories?
# NO trailing slash!
# the owner of the parent directory must be "root"!
USERPATH=/var/www/users

# which group is used to catch and jail users into their sftp chroot?
SFTPGROUP=sftponly



### DO NOT EDIT BELOW! ###

### TODO
# add blocklist/keeplist
# add update/refresh keys on existing user
# make sure concealed members are grabbed as well: https://docs.github.com/en/rest/orgs/members?apiVersion=2022-11-28#list-organization-members


# check for root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
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
    echo "    ChrootDirectory $PATUSERH/%u"
    echo "    ForceCommand internal-sftp"
    echo "    AllowTcpForwarding no"
    exit 1
fi



# grab a list of current remote org members and make it comparable
ORGMEMBERS=$(curl -s https://api.github.com/orgs/armbian/members | jq -r ".[].login")
# Grab a list of local directories and make it comparable
# We assume that existing directory means locally existing user as well
LOCALMEMBERS=$(echo -n "`ls members/`")
LOCALMEMBERS_COMP=$(echo -n "`ls members/`" | sed 's/\ /|/g' |sed -r 's/^/\(/'  |sed -r 's/$/\)/')


# loop through remote org members and add if not existing
for i in $ORGMEMBERS; do

    if ! [[ $i =~ $LOCALMEMBERS_COMP ]]; then # skip locally already existing users

        # create local user and directory
        echo " $i - no local directory found. Creating..."
        if ! useradd -m -s /bin/bash -G $SFTPGROUP -d $USERPATH/"$i" "$i"
        then
            echo "$i's directory could not be created for whatever reason"
            exit 1
        fi
        echo "$i directory created"

        # grab ssh keys and put into user's .ssh/authorized_keys file
        echo "Trying to grab ssh keys"
        mkdir -p $USERPATH/"$i"/.ssh
        curl -s https://github.com/"$i".keys > "$USERPATH"/"$i"/.ssh/authorized_keys
        chown -R "$i":$SFTPGROUP "$USERPATH"/"$i"/.ssh
        chmod 600 $USERPATH/"$i"/.ssh/authorized_keys

        # Check if grabbed stuff are actual ssh keys
        CHECK_KEYS=$(cat $USERPATH/"$i"/.ssh/authorized_keys|grep -c -E "^ssh")
        if [[ $CHECK_KEYS != 0 ]]; then
            echo "$i - $CHECK_KEYS key/s for $i imported"
        else
            echo "$i - Either grabbing failed or $i does not have ssh key on git"
            echo "$i won't be able to login"
            rm $USERPATH/"$i"/.ssh/authorized_keys
        fi

    else
        echo "$i - local directory found. Skipping..."
        # TODO: update ssh keys here
    fi
done

# remove local users not exsting in remote org
ORGMEMBERS_COMP=$(echo -n "`curl -s https://api.github.com/orgs/armbian/members | jq -r ".[].login"`" | sed 's/\ /|/g' |sed -r 's/^/\(/'  |sed -r 's/$/\)/')

for i in $LOCALMEMBERS; do

    if ! [[ $i =~ $ORGMEMBERS_COMP ]]; then # compare local user against list of remote org members. If not found carry on
        echo "$i is not in the list of remote org members. Removing its legacy..."
        userdel --remove "$i"
    else
        echo "$i is still member of remote org. Skipping..."
    fi
done
