#!/usr/bin/env bash

set +x
set +e

touch $HOME/.bash_profile
source $HOME/.bash_profile

sudo="sudo -A"
who=`whoami`

#exit 0


###=========================================

echox() { 
    local b t e 
    [ $# -le 2 ] && return
    b="\033[${1}m" && shift
    t=${1} && shift 
    e="\033[00m"
    printf "${b}${t}${e} $*\n" 
}

echop() {
    echo
    echox 34 "###==============================" ""
    echox 34 "[*] Process $*" ""
    eval "$*"
    echox 35 "[*] Return: $?" ""
    echo
}

check_pkg() {
    [ $# -ne 1 ] && return 1
    which $1 2>/dev/null || return 1
    return 0
}

check_install() {
    local force opts args
    local tool bin pkg
    force=""
    opts="t:b:p:f"; 
    args=`getopt $opts $*`; [ $? != 0 ] && return 1
    set -- $args
    for i; do
        case "$i" in
            -t) 
                tool=$2; shift;
                shift;;
            -b)
                bin=$2; shift;
                shift;;
            -p)
                pkg=$2; shift;
                shift;;
            -f)
                force="true"; 
                shift;;
            --)
                shift; break;;
        esac
    done

    [ "$tool" = "" -o "$bin" = "" ] && return 1
    [ "$pkg" = "" ] && pkg="$bin"

    if [ "$force" != "" ]; then
        echox 33 "===== FORCE INSTALL: $tool install $pkg =====" ""
    else
        check_pkg $bin && return 0
        echox 33 "===== FRESH INSTALL: $tool install $pkg =====" ""
    fi
    $tool install $pkg
    check_pkg $bin && return 0 || return 1
}

brew_install() {
    check_install -t brew $* && return 0 || return 1
}

gem_install() {
    check_install -t gem $* && return 0 || return 1
}



###=========================================

check_env() {
    local user config
    local dlist dname bname
    if ! [[ "$PATH" =~ "/usr/local/bin" ]]; then
        echo "export PATH=/usr/local/bin:\$PATH" >> ~/.bash_profile
        export PATH=/usr/local/bin:$PATH
    fi

    dlist=(/usr/local /opt/local /Library/Caches/Homebrew /Library/Ruby/Gems)
    for item in ${dlist[@]}; 
    do
        dname=`dirname $item`
        bname=`basename $item`
        user=`ls -l $dname | grep " $bname$" | awk '{print $3}'`
        if [ "$user" != "$who" ]; then
            $sudo mkdir -p $item
            $sudo chown -R $who:wheel $item
        fi
    done

    $sudo mkdir -p /opt/local/bin

    config=$HOME/.ssh/config && touch $config
    cat $config | grep "StrictHostKeyChecking no" || echo "StrictHostKeyChecking no" >> $config

    return 0
}

check_brew() {
    check_pkg brew && return 0 
    check_pkg ruby || return 1
    rm -rf /usr/local/Cellar /usr/local/.git && brew cleanup
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    return 0
}

check_sshkey() {
    [ -f $HOME/.ssh/id_rsa ] && return 0
    ssh-keygen -f $HOME/.ssh/id_rsa -P ""
    return 0
}

check_utils() {
    brew_install -b wget || return 1
    brew_install -b ant || return 1
    brew_install -b cmake || return 1
    return 0
}

check_nodejs() {
    brew_install -b node || return 1
    brew_install -b npm || return 1
    return 0
}

check_ruby() {
    local ver
    check_pkg ruby || return 1
    check_pkg rvm || curl -sSL https://get.rvm.io | bash -s stable --ruby
    check_pkg rvm || return 1
    
    ver=`ruby --version | awk '{print $2}'`  
    if ! [[ "$ruby_version" =~ "2.1.2" ]]; then
        rvm list | grep 2.1.2 2>/dev/null 1>&2 || rvm install 2.1.2 2>/dev/null
        rvm --default --create use 2.1.2 2>/dev/null 1>&2
    fi

    return 0
}

check_nasm() {
    local has_nasm nasm nasm_uri pkg
    has_nasm=0
    check_pkg nasm && nasm -version | grep "2.11" && has_nasm=1
    [ $has_nasm -eq 1 ] && pkg=`which nasm 2>/dev/null`

    nasm="/opt/local/bin/nasm"
    [ -f $nasm ] && $nasm -version | grep "2.11" && has_nasm=2

    if [ $has_nasm -eq 0 ]; then
        nasm_uri="http://www.nasm.us/pub/nasm/releasebuilds/2.11.06/macosx/nasm-2.11.06-macosx.zip"
        wget $nasm_uri -O /tmp/nasm.zip

        unzip /tmp/nasm.zip -d /opt/local/
        pkg="/opt/local/nasm-2.11.06/nasm"
    fi

    [ $has_nasm -ne 2 ] && rm -f $nasm && ln -s $pkg $nasm
    return 0
}



###=========================================

check_android() {
    brew_install -b android -p android-sdk || return 1
    brew_install -b ndk-build -p android-ndk || return 1

    if [ "$ANDROID_HOME" = "" ]; then
        echo "export ANDROID_HOME=/usr/local/opt/android-sdk" >> ~/.bash_profile
        export ANDROID_HOME=/usr/local/opt/android-sdk
    fi

    if [ "$ANDROID_NDK_HOME" = "" ]; then
        echo "export ANDROID_NDK_HOME=/usr/local/opt/android-ndk" >> ~/.bash_profile
        export ANDROID_NDK_HOME=/usr/local/opt/android-ndk
    fi

    if [ "$ANDROID_NDK" = "" ]; then
        echo "export ANDROID_NDK=\$ANDROID_NDK_HOME" >> ~/.bash_profile
    fi

    if ! [[ "$PATH" =~ "/platform-tools" ]]; then
        echo "export PATH=\$ANDROID_HOME/platform-tools:\$PATH" >> ~/.bash_profile
        export PATH=$ANDROID_HOME/platform-tools:$PATH
    fi
    return 0
}

check_xcode() {
    brew_install -b xctool || return 1
    check_pkg xcodebuild || return 1
    check_pkg ios-deploy || npm install -g ios-deploy
    check_pkg ios-deploy || return 1
    return 0
}

check_calabash() {
    local ver
    check_pkg gem || return 1
    check_pkg rvm || return 1

    ver=""
    check_pkg cucumber && ver=$(cucumber --version 2>/dev/null)
    echo "cucumber version: $ver"
    if [ "$ver" != "1.3.18" ]; then 
        gem uninstall cucumber --force
        gem install cucumber -v 1.3.18
        rvm get stable --auto-dotfiles
    fi
    check_pkg cucumber || return 1

    rvm gemset list | grep "=> calabash" 2>/dev/null
    if [ $? -ne 0 ]; then
        rvm use default
        rvm gemset create calabash
        rvm gemset use calabash
    fi
    # bundle init && bundle install

    gem list | grep "^calabash " 2>/dev/null || gem install calabash
    gem list | grep "^calabash-android " 2>/dev/null || gem install calabash-android

    return 0
}




###=========================================

[ $# -ne 1 ] && echo "usage: sh_mac.sh task" && exit 0
target=$1


tasks=("env" "brew" "utils" "sshkey" "nodejs" "ruby" "nasm" "android" "xcode" "calabash")
for task in ${tasks[@]}; 
do
    if [ $target = $task -o $target = "all" ]; then
        echop "check_$task"
    fi
done


exit 0
