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

    HOME="/home/$USER"
    cfg="/usr/bin/git --git-dir=$HOME/.cfgrepo/ --work-tree=$HOME"
    secret="/usr/bin/git --git-dir=$HOME/.identity/ --work-tree=$HOME"

    # interactive part

    git init --bare $HOME/.identity

    $secret remote add first https://github.com/sneusse/identity.git
    $secret fetch first
    $secret reset --hard first/master

    # hide my private key
    chmod 400 ~/.ssh/id_rsa

    # load ssh key
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
    ssh -oStrictHostKeyChecking=no -T git@github.com

    # now that we have the privatekey...
    $secret remote remove first
    $secret remote add origin git@github.com:sneusse/identity.git
    $secret fetch origin
    $secret reset --hard origin/master
    $secret pull origin master
    $secret branch --set-upstream-to=origin/master master

    git init --bare $HOME/.cfgrepo
    $cfg remote add origin git@github.com:sneusse/dotfiles.git
    $cfg reset --hard origin/master

    # change shell
    sudo chsh -s /bin/zsh $NEWUSER

    sudo updatedb

    exec zsh
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
pv
mc
EOF

# check/add sudo for our user
if ! grep -q "$NEWUSER ALL" /etc/sudoers; then
    echo "$NEWUSER ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
fi

# disable ssh with password
if ! grep -q -e "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    echo "PasswordAuthentication no" >>/etc/ssh/sshd_config
fi

# reset port for ssh
if ! grep -q -e "^Port 20002" /etc/ssh/sshd_config; then
    echo "Port 20002" >>/etc/ssh/sshd_config
fi

# gen locale US
if ! grep -q -e "^en_US" /etc/locale.gen; then
    echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
fi

# gen locale DE
if ! grep -q -e "^de_DE" /etc/locale.gen; then
    echo de_DE.UTF-8 UTF-8 >> /etc/locale.gen
fi

# set locale
locale-gen
localectl set-locale LANG=en_US.UTF-8

# setup trizen
su $NEWUSER <<EOF
git clone https://aur.archlinux.org/trizen.git
cd trizen
makepkg -sir --noconfirm
EOF

# execute user init script
runuser -u $NEWUSER bash $SCRIPT

systemctl restart sshd
echo "login with ssh to your new user!"
