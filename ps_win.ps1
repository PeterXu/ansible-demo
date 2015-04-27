
function set_env($name, $value) {
    if ($value -eq "") {
        return
    }
    if ($name -ne "Path") {
        [System.Environment]::SetEnvironmentVariable($name, $value, 'User')
    }
}

function set_path($value) {
    if ($value -eq "") {
        return
    }
    if ($env:Path.IndexOf($value) -eq -1) {
        $env:Path += ";$value"
        [System.Environment]::SetEnvironmentVariable('Path', $env:Path, 'User')
    }
}

function refresh_env {   
    $locations = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment','HKCU:\Environment'
    $locations | ForEach-Object {   
        $k = Get-Item $_
        $k.GetValueNames() | ForEach-Object {
            $name  = $_
            $value = $k.GetValue($_)
            Set-Item -Path Env:\$name -Value $value
        }
    }
}

function send_msg {
    if (-not ("Win32.NativeMethods" -as [Type])) {
        # import sendmessagetimeout from win32
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
    }

    $HWND_BROADCAST = [IntPtr] 0xffff;
    $WM_SETTINGCHANGE = 0x001a;
    $result = [UIntPtr]::Zero;
    $flags = 0x0002;
                                                              
    # notify all windows of environment block change
   [Win32.Nativemethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", $flags, 5000, [ref] $result);
}

function check_install($bin, $pkg, $opt, $path) {
    $ret = "False"
    if ($bin -ne "") {
        cmd /C where $bin
        $ret = $?
    }
    if ($ret -eq "False") {
        echo "[WARN] To install $pkg ..."
        cinst $pkg -y $opt
        set_path "$path"
    }
}



##======================================

function check_env {
    if ($env:Home -ne $env:UserProfile) {
        set_env "HOME" "$env:UserProfile"
    }
}

function check_base {
    check_install -bin whois -pkg sysinternals -path "C:\Tools\sysinternals"
    check_install -bin 7z -pkg 7zip -opt "-f" -path "C:\Program Files\7-Zip"
    check_install -bin cmake -pkg cmake
    check_install -pkg freeSSHD
}

function check_dev {
    $ant_home = "C:\Tools\apache-ant-1.9.4"
    check_install -bin ant -pkg ant -opt "-f" -path "$ant_home\bin"
    if ($env:ANT_HOME -ne $ant_home) {
        set_env "ANT_HOME" "$ant_home"
    }
    
    cmd /C where git
    if ($? -eq "False") {
        cinst git --params="/GitAndUnixToolsOnPath /NoAutoCrlf" -y -f
    }

    check_install -bin cygwin -pkg cygwin -opt "-f" -path "C:\Tools\cygwin\bin"
    check_install -bin nasm -pkg nasm -opt "-f" -path "C:\Users\testbed\AppData\Local\nasm" 
}


function check_python
{
    check_install -bin python -pkg python2 -opt "-f"
    pip install python-dateutil
    pip install numpy
    pip install matplotlib docutils sphinx treelib
    pip install pymatlab scipy
}

function check_ruby
{
    check_install -bin ruby -pkg ruby -opt "-f"
    check_install -pkg rubygems
    check_install -bin -pkg ruby2.devkit -opt "-f"
    check_install -bin node -pkg nodejs.install -opt "-f"
}

function check_android
{
    check_install -bin android -pkg android-sdk
    #cinst android-ndk -y --source=http://dl.google.com/android/ndk/android-ndk-r10d-windows-x86_64.exe
}

function check_calabash
{
    gem update --system 2.3.0
    gem install erubis

    gem uninstall cucumber --force
    gem install cucumber -v 1.3.18

    rvm use default
    rvm gemset create calabash
    rvm gemset use calabash

    #gem list | grep "^calabash " 2>/dev/null || gem install calabash
    #gem list | grep "^calabash-android " 2>/dev/null || gem install calabash-android
}

#########################
# prepare installed tools
#   visual studio
#   java7
#   android sdk
#   android ndk
#########################

check_env
check_base
check_dev
#check_python
#check_ruby
