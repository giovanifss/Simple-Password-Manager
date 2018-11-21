#!/bin/sh

path="/usr/local/bin"

if [ -w "${path}" ]; then
    cp "$(pwd)/password-manager/password-manager.sh" "${path}/password-manager"
else
    sudo cp "$(pwd)/password-manager/password-manager.sh" "${path}/password-manager"
fi	
