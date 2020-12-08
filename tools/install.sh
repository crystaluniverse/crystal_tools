#!/bin/bash

# this script to install tfweb and conscious_internet
# tfweb port is 3000

set +ex

if [[ "$OSTYPE" != "darwin"* ]] && [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo OS is not supported ..
    exit 1
fi

echo " - INSTALL DEPENDENCIES"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "make sure git, mc, tmux installed" 
    if ! [ -x "$(command -v mc)" ]; then
    apt update
    apt install mc -y
    fi    

    if ! [ -x "$(command -v curl)" ]; then
    apt install curl -y
    fi    

    if ! [ -x "$(command -v wget)" ]; then
    apt install curl -y
    fi    

    if ! [ -x "$(command -v yarn)" ]; then
    apt install yarn -y
    fi    

    if ! [ -x "$(command -v git)" ]; then
    apt install git -y
    fi

    if ! [ -x "$(command -v tmux)" ]; then
    apt install tmux -y
    fi

    if ! [ -x "$(command -v rsync)" ]; then
    apt install rsync -y
    fi
fi
    

if [[ "$OSTYPE" == "darwin"* ]]; then

    set +ex

    if ! [ -x "$(command -v brew)" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    fi
    
    if ! [ -x "$(command -v mc)" ]; then
    brew install mc
    fi    
    
    brew install libyaml

    if ! [ -x "$(command -v git)" ]; then
    brew install git
    fi

    if ! [ -x "$(command -v wget)" ]; then
    brew install wget
    fi    

    if ! [ -x "$(command -v tmux)" ]; then
    brew install tmux
    fi

    if ! [ -x "$(command -v yarn)" ]; then
    brew install yarn
    fi    

    if ! [ -x "$(command -v rsync)" ]; then
    brew install rsync
    fi    

#     if ! [ -x "$(command -v gnuplot)" ]; then
#     brew install gnuplot
#     fi

fi

ssh-keygen -F github.com || ssh-keyscan github.com >> ~/.ssh/known_hosts
    
rm -f /usr/local/bin/ct 2>&1 > /dev/null

set +ex

echo " - DOWNLOAD CT TOOLS"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    set -e
    cd /tmp
    rm -f /tmp/ct_linux
    wget https://github.com/crystaluniverse/crystaltools/releases/download/v1.0/ct_linux
    cp  ct_linux /usr/local/bin/ct

fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    set -e
    cd /tmp
    rm -f /tmp/ct_osx
    wget https://github.com/crystaluniverse/crystaltools/releases/download/v1.0/ct_osx
    cp ct_osx /usr/local/bin/ct
fi

echo " - DOWNLOAD OK"

chmod 770 /usr/local/bin/ct

if ! [ -x "$(command -v ct)" ]; then
echo 'Error: ct (crystaltools) did not install' >&2
exit 1
fi

ct -h

echo "CONGRATS CRYSTAL TOOLS ARE NOW INSTALLED"
