
function set_env($name, $value) 
{
    if ($value -eq "") {
        return
    }
    if ($name -ne "Path") {
        [System.Environment]::SetEnvironmentVariable($name, $value, 'User')
    }
}

function set_path($value) 
{
    if ($value -eq "") {
        return
    }
    if ($env:Path.IndexOf($value) -eq -1) {
        $env:Path += ";$value"
        [System.Environment]::SetEnvironmentVariable('Path', $env:Path, 'User')
    }
}

function refresh_env 
{
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

function send_msg 
{
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

function check_install([string]$bin, $pkg, $opt, [string]$ver, $path) 
{
    $ret = False
    if ($bin.Length -ne 0) {
        cmd /C where $bin
        $ret = $?
    }
    if (!$ret) {
        echo "[WARN] To install $pkg ..."
        if ($ver.Length -ne 0) {
            cinst $pkg -y $opt -version="$ver"
        }else {
            cinst $pkg -y $opt
        }
        set_path "$path"
    }
}

function pip_install($pkg)
{
    pip list $pkg | grep "^$pkg "
    pip install $pkg
}



##======================================

function check_env 
{
    if ($env:Home -ne $env:UserProfile) {
        set_env "HOME" "$env:UserProfile"
    }
}

function check_base 
{
    #check_install -bin whois -pkg sysinternals -path "C:\Tools\sysinternals"
    check_install -bin 7z -pkg 7zip -opt "-f" -path "C:\Program Files\7-Zip"
    check_install -bin cmake -pkg cmake
    check_install -pkg freeSSHD
}

function check_dev 
{
    $ant_home = "C:\Tools\apache-ant-1.9.4"
    check_install -bin ant -pkg ant -opt "-f" -ver "1.9.4" -path "$ant_home\bin"
    if ($env:ANT_HOME -ne $ant_home) {
        set_env "ANT_HOME" "$ant_home"
    }
    
    cmd /C where git
    $ret = $?
    if (!$ret) {
        cinst git.install --params="/GitAndUnixToolsOnPath /NoAutoCrlf" -y
        set_path "C:\Program Files (x86)\Git\bin"
    }

    check_install -bin cygwin -pkg cygwin -opt "-f" -path "C:\Tools\cygwin"
    set_path "C:\Tools\cygwin\bin"

    check_install -bin nasm -pkg nasm -opt "-f" -path "C:\Users\testbed\AppData\Local\nasm" 
}


function check_python
{
    check_install -bin python -pkg python2 -opt "-f"
    cmd /C where pip
    $ret = $?
    if (!$ret) {
        echo "Cannot find pip for python ..."
        return
    }

    pip_install -pkg python-dateutil
    #pip_install -pkg numpy
    #pip_install -pkg matplotlib 
    #pip_install -pkg pymatlab
    #pip_install -pkg scipy
    pip_install -pkg docutils 
    pip_install -pkg sphinx 
    pip_install -pkg treelib 
}

function check_android
{
    check_install -bin android -pkg android-sdk
    #cinst android-ndk -y --source=http://dl.google.com/android/ndk/android-ndk-r10d-windows-x86_64.exe
}

function check_ruby
{
    check_install -bin ruby -pkg ruby -opt "-f" -ver "2.1.5" -path "C:\Tools\ruby215\bin"
    check_install -pkg rubygems

    check_install -bin devkitvars -pkg ruby2.devkit -path "C:\tools\DevKit2"
    set_path "C:\tools\DevKit2\bin"
    
    Push-Location
    cd "C:\tools\DevKit2"
    ruby dk.rb init
    ruby dk.rb install
    Pop-Location

    check_install -bin node -pkg nodejs.install -opt "-f"
}

function check_calabash
{
    #gem sources -r https://rubygems.org/
    #gem sources -a http://rubygems.org/

    $fprc="$env:HOME\.gemrc"
    echo "=> generating $fprc"
    #Copy-Item $root\update\.gemrc $env:HOME\.gemrc -Force
    
    echo "---"                      | out-file -filePath $fprc -encoding ASCII
    echo ":backtrace: false"        | out-file -filePath $fprc -encoding ASCII -Append
    echo ":bulk_threshold: 1000"    | out-file -filePath $fprc -encoding ASCII -Append
    echo ":sources:"                | out-file -filePath $fprc -encoding ASCII -Append
    echo "- http://rubygems.org"    | out-file -filePath $fprc -encoding ASCII -Append
    echo ":update_sources: true"    | out-file -filePath $fprc -encoding ASCII -Append
    echo ":verbose: true"           | out-file -filePath $fprc -encoding ASCII -Append
    #return


    gem update --system 2.3.0

    gem list erubis -i 
    $ret = $?
    if (!$ret) {
        gem install erubis
    }
    
    gem list cucumber -i -v 1.3.18
    $ret = $?
    if (!$ret) {
        gem uninstall cucumber --force
        gem install cucumber -v 1.3.18
    }

    gem list -l | grep "^calabash " 
    $ret = $?
    if (!$ret) {
        gem install calabash
    }

    gem list -l | grep "^calabash-android " 
    $ret = $?
    if (!$ret) {
        gem install calabash-android
    }
}




#########################
# prepare installed tools
#   visual studio
#   java7
#   android sdk
#   android ndk
#########################


$root = Split-Path -Parent $MyInvocation.MyCommand.Definition

check_env
check_base
check_dev
check_python
check_ruby
check_calabash

exit 0
