
#!/bin/bash
set -ex

if [[ "$1" == pull || "$2" == pull ]]
then
    # echo PULL
    PULL=1
else
    PULL=0
fi

if [[ "$1" == reset || "$2" == reset ]]
then
    # echo RESET
    RESET=1
else
    RESET=0
fi

if [[ "$OSTYPE" != "darwin"* ]] && [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo OS is not supported ..
    exist 1
fi

if ! [ -x "$(command -v crystal)" ]; then

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        apt-get install -y build-essential curl libevent-dev libssl-dev libxml2-dev libyaml-dev libgmp-dev wget

        if ! [ -x "$(command -v crystal)" ]; then
            curl -sSL https://dist.crystal-lang.org/apt/setup.sh |  bash ; \
            curl -sL "https://keybase.io/crystal/pgp_keys.asc" |  apt-key add - ; \
            echo "deb https://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list  ; \
            apt-get update  ; \
            apt install crystal -y

        fi
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then

        if ! [ -x "$(command -v crystal)" ]; then

            if ! [ -x "$(command -v brew)" ]; then
            echo 'Error: brew is not installed, please do so' >&2
            exit 1
            fi
        
        fi

        brew install crystal
        brew install git
        # brew install node
    fi
        
fi


if ! [ -x "$(command -v git)" ]; then
echo 'Error: git is not installed, please install git' >&2
exit 1
fi


export DEST=~/code/github/crystaluniverse/

if [ -d "$DEST/crystaltools" ] ; then
    cd $DEST/crystaltools
    if [ "$PULL" = "1" ]; then git pull; fi
else
    mkdir -p $DEST
    cd $DEST
    git clone "git@github.com:crystaluniverse/crystaltools"
fi
mkdir -p $DEST/crystaltools/lib
if [ -d "$DEST/crystaldocker" ] ; then
    cd $DEST/crystaldocker
    if [ "$PULL" = "1" ]; then git pull; fi
else
    mkdir -p $DEST
    cd $DEST
    git clone "git@github.com:crystaluniverse/crystaldocker"
fi

if ! [ -L $DEST/crystaltools/lib/crystaldocker ]; then
echo "- LINK CRYSTALDOCKER"
ln -sf "$DEST/crystaldocker" "$DEST/crystaltools/lib/crystaldocker"
fi

cd $DEST/crystaltools

if [ "$RESET" = "1" ]
then
    rm -f /usr/local/bin/ct
fi

if ! [ -x "$(command -v ct)" ]; then
    bash build.sh
fi


if ! [ -x "$(command -v ct)" ]; then
    echo 'Error: crystal tools did not build' >&2
    exit 1
fi

