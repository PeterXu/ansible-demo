function check_calabash
{
    gem uninstall cucumber --force
    gem install cucumber -v 1.3.18

    rvm use default
    rvm gemset create calabash
    rvm gemset use calabash

    gem list | grep "^calabash " 2>/dev/null || gem install calabash
    gem list | grep "^calabash-android " 2>/dev/null || gem install calabash-android
}


dir
