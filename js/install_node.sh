#!/usr/bin/env bash

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "\nMust run script as root."
    exit
fi

# Add the NodeSource package signing key
curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -

# Add the desired NodeSource repository
VERSION=node_20.x
# The below command will set this correctly, but if lsb_release isn't available, you can set it manually:
# - For Debian distributions: jessie, sid, etc...
# - For Ubuntu distributions: xenial, bionic, etc...
DISTRO="$(lsb_release -s -c)"
echo "deb https://deb.nodesource.com/$VERSION $DISTRO main" | tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src https://deb.nodesource.com/$VERSION $DISTRO main" | tee -a /etc/apt/sources.list.d/nodesource.list

# Update package lists and install Node.js
apt-get update
apt-get install nodejs -y
