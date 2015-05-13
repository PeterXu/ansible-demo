#!/usr/bin/env bash

profile=""
[ -f $HOME/.profile ] && profile=$HOME/.profile
[ -f $HOME/.bashrc ] && profile=$HOME/.bashrc
[ -f $HOME/.bash_profile ] && profile=$HOME/.bash_profile
if [ "$profile" = "" ]; then
    echo "fail to set ansible for user: $(whoami)"
    exit 1
fi

which brew 2>/dev/null || exit 1


# For python 2.7
brew install python
py=$(which python 2>/dev/null)
if [ "$py" != "/usr/local/bin/python" ]; then
    echo "export PATH=/usr/local/bin:\$PATH" >> $profile
    export PATH=/usr/local/bin:$PATH
fi
python get-pip.py


# For ansible
brew update
brew install ansible
brew upgrade ansible
pip install pywinrm kerberos pykerberos


ver=$(ansible --version | grep "ansible" | awk '{print $2}')
if [ "$ver" = "1.9.0.1" ]; then
    echo "Should fix some bugs for ansible-$ver"
    echo "Please refer to https://github.com/cchurch/ansible/commit/5675982b0f64cbc3bf01eff63951d1302132c6d2"
elif [ "$ver" = "1.9.1" ]; then
    cp -f update/winrm.py /usr/local/Cellar/ansible/1.9.1/libexec/lib/python2.7/site-packages/ansible/runner/connection_plugins/winrm.py
fi

rm -rf $HOME/.ansible
ln -s `pwd` $HOME/.ansible

if [ "$ANSIBLE_CONFIG" = "" ]; then
    echo "export ANSIBLE_CONFIG=\$HOME/.ansible/ansible.cfg" >> $profile
    export ANSIBLE_CONFIG=$HOME/.ansible/ansible.cfg
fi


exit 0
