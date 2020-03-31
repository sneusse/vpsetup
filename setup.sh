#!/bin/bash

if [ -z "$NEWUSER" ]; then
    echo "set the NEWUSER variable!"
    exit 1
fi

if [ -z "$NEWPASS" ]; then
    echo "set the NEWPASS variable!"
    exit 1
fi

# save our path
SCRIPT=`realpath $0`

# user context
if [ "$USER" == "$NEWUSER" ]; then
    cd ~
    echo "------------------------------------------------------"
    echo "changing to: $(pwd) as user '$(whoami)'"
    echo "   some stuff will be interactive!"
    echo "------------------------------------------------------"
    trizen --noconfirm --needed -S micro
    trizen --noconfirm -Sc

    # interactive part
    git init
    git remote add first https://github.com/sneusse/dofiles.git
    git pull first master

    # hide my private key
    chmod 400 ~/.ssh/id_rsa

    # change shell
    sudo chsh -s /bin/zsh $NEWUSER

    # load ssh key
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    ssh -oStrictHostKeyChecking=no -T git@github.com

    # now that we have the privatekey...
    git remote remove first
    git remote add origin git@github.com:sneusse/dofiles.git
    git fetch origin master
    git branch --set-upstream-to=origin/master master

    sudo updatedb
    echo "all done!"
    exit 
fi

# upgrade everything first
pacman -Syu --noconfirm

# add user
useradd -m $NEWUSER
echo $NEWUSER:$NEWPASS | chpasswd

SCRATCH=/tmp/setup
# create folder and give all permissions to our new user
mkdir -p $SCRATCH && cd $SCRATCH && chown $NEWUSER .

# install base packages
pacman --needed --noconfirm -S - <<EOF
sudo
git
nano
zsh
tmux
htop
bmon
mtr
base-devel
mlocate
man
wget
EOF

# check/add sudo for our user
if ! grep -q "$NEWUSER ALL" /etc/sudoers; then
    echo "$NEWUSER ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
fi

# setup trizen
su $NEWUSER <<EOF
git clone https://aur.archlinux.org/trizen.git
cd trizen
makepkg -sir --noconfirm
EOF

# execute user init script
runuser -u $NEWUSER bash $SCRIPT

echo "login with ssh to your new user!"