#!/usr/bin/env bash

# WARNING: This script changes the image for ALL users
# on a single machine excluding users whose name begins
# with '_' and the users daemon, Guest, nobody and root.
# It is provided for demonstration purposes only. If you
# wish to use it, comment-out the line below.

printf "Script terminated.\n"; exit 1      # Comment-out this line to run the script in its entirety.

for U in $(dscl . list /Users | grep -v "^_"); do

    EXCLUDE=(daemon Guest nobody root)

    if [[ ! " ${EXCLUDE[@]} " =~ " $U " ]]; then
        ./set-user-image.sh -u $U -i images/giraffe.jpg
    fi

done