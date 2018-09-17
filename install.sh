#!/bin/bash

userID=""
database=""
path="/usr/local/bin/password-manager"

sed -i -e 's|<USER-ID>|'"$userID"'|g' -e 's|<DATABASE>|'"$database"'|g' password-manager/password-manager.sh
if [ -w "$path" ]; then
    ln -s "$(pwd)/password-manager/password-manager.sh" "/usr/local/bin/password-manager"
else
    sudo ln -s "$(pwd)/password-manager/password-manager.sh" "/usr/local/bin/password-manager"
fi	
