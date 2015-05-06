# powershell for windows
# - yongzxu@cisco.com
#


##======================================
# global vars
#
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition

$tool_home = "C:\Tools"
$cyg_home = "C:\Tools\cygwin"
$choco_home = "C:\ProgramData\chocolatey"

$env_change = 0
$env_home = "$env:UserProfile"
$env_who = "$env:username"
$computer = "$env:computername"

echo "[=] uname: $env_who, home: $env_home, computer: $computer"


##======================================
# util functions
#
function set_env($name, $value) 
{
    if ($value -eq "") {
        return
    }
    if ($name -ne "Path") {
        [System.Environment]::SetEnvironmentVariable($name, $value, 'User')
        $env_change = 1
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
        $env_change = 1
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

function check_logoff
{ 
    if ($env_change -eq 0) {
        return
    }

    #0            Log Off
    #4            Forced Log Off (0+4)
    #1            Shutdown
    #5            Forced Shutdown (1+4)
    #2            Reboot
    #6            Forced Reboot (2+4)
    #8            Power Off
    #12           Forced Power Off (8+4)
    (Get-WMIObject -class Win32_OperatingSystem -Computername $computer).Win32Shutdown(0)
}

function reload_env
{
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $env:Path += [System.Environment]::GetEnvironmentVariable("Path","User")
}
        


##======================================
# install functions
#
function check_install([string]$bin, $pkg, $opt, [string]$ver, $path) 
{
    if ($bin.Length -ne 0) {
        cmd /C where $bin
        $ret = $?
    }

    if (!$ret) {
        echo "[WARN] To install $pkg by choco ..."
        if ($ver.Length -ne 0) {
            cinst $pkg -y $opt -version="$ver"
        }else {
            cinst $pkg -y $opt
        }
        Start-Sleep -s 30
        set_path "$path"
    }
}

function cyg_install([string]$bin, $pkg)
{
    if ($bin.Length -ne 0) {
        cmd /C where $bin
        $ret = $?
    }

    if (!$ret) {
        echo "[WARN] To install $pkg by cyg-get ..."
        cyg-get $pkg
        Start-Sleep -s 30
    }
}

function pip_install($pkg)
{
    pip list | grep "^$pkg "
    $ret = $?
    if (!$ret) {
        pip install $pkg
    }
}

function gem_install($pkg, [string]$ver)
{
    if ($ver.Length -ne 0) {
        gem list -l | grep "^$pkg ($ver)"
        $ret = $?
        if (!$ret) {
            gem uninstall $pkg --force
            gem install $pkg -v $ver
        }
    }else {
        gem list -l | grep "^$pkg "
        $ret = $?
        if (!$ret) {
            gem install $pkg
        }
    }
}



##======================================
# check functions
#
function check_env 
{
    if ($env:HOME -ne $env_home) {
        set_env "HOME" "$env_home"
    }
    set_path "$choco_home\bin"
    reload_env
}

function check_ant 
{
    $ant_home = "$tool_home\apache-ant-1.9.4"

    set_path "$ant_home\bin"
    if ($env:ANT_HOME -ne $ant_home) {
        set_env "ANT_HOME" "$ant_home"
    }
    reload_env
}

function check_cygwin
{
    $cyg_ps = "$choco_home\lib\cyg-get\tools\cyg-get.ps1"

    set_path "$cyg_home"
    set_path "$cyg_home\bin"
    reload_env

    cat $cyg_ps | grep 'replace("" "","","")'
    $ret = $?
    if (!$ret) {
        sed -i 'N;/$cygPackages = join-path $cygRoot packages/a\    $package = $package  -replace("" "","","")' $cyg_ps
    }

    cat $cyg_ps | grep "ftp://"
    $ret = $?
    if ($ret) {
        sed -i "s#ftp://#http://#" $cyg_ps
    }
}

function check_tools
{
    $pkgs = "nasm,curl,wget,git,openssh,p7zip,cmake,python"
    cyg-get "$pkgs"

    cmd /C where 7z.bat
    $ret = $?
    if (!$ret) {
        $cmdfile = "$cyg_home\bin\7z.bat" 
        echo "$cyg_home\lib\p7zip\7z.exe %*" | out-file -filePath $cmdfile -encoding ASCII
    }

    cmd /C where python.bat
    $ret = $?
    if (!$ret) {
        cmd /C where python2.7
        $ret = $?
        if ($ret) {
            $cmdfile = "$cyg_home\bin\python.bat" 
            echo "python2.7 %*" | out-file -filePath $cmdfile -encoding ASCII
        }
    }

    cmd /C where pip.bat
    $ret = $?
    if (!$ret) {
        $src = "https://bootstrap.pypa.io/get-pip.py"
        $dest = "$env_home\get-pip.py"
        Remove-Item $dest -Force
        Invoke-WebRequest $src -OutFile $dest
        python $dest

        $cmdfile = "$cyg_home\bin\pip.bat" 
        echo "python /usr/bin/pip %*" | out-file -filePath $cmdfile -encoding ASCII
    }
}

function check_ssh
{
    cmd /C ls $env_home\.ssh\id_rsa 
    $ret = $?
    if (!$ret) {
        ssh-keygen -t rsa -C "tesbed@$computer" -f $env_home\.ssh\id_rsa -q -N "''"
    }

    cmd /C $cyg_home\bin\bash.exe /usr/bin/ssh-host-config -y -u testbed -w "wme@cisco"
    run /usr/sbin/sshd
}

function check_python
{
    cmd /C where pip
    $ret = $?
    if (!$ret) {
        return
    }

    pip_install -pkg python-dateutil
    pip_install -pkg numpy
    pip_install -pkg matplotlib 
    pip_install -pkg pymatlab
    pip_install -pkg scipy
    pip_install -pkg docutils 
    pip_install -pkg sphinx 
    pip_install -pkg treelib 
}

function check_ruby
{
    set_path "$tool_home\ruby215"
    set_path "$tool_home\ruby215\bin"
    reload_env

    set_path "$tool_home\DevKit2"
    set_path "$tool_home\DevKit2\bin"
    reload_env

    Push-Location
    cd "$tool_home\DevKit2"
    ruby dk.rb init
    sed -i 's#C:/Ruby193#C:\Tools\ruby215#' config.yml
    ruby dk.rb install
    Pop-Location

    reload_env
}

function check_calabash
{
    #gem sources -r https://rubygems.org/
    #gem sources -a http://rubygems.org/

    $fprc="$env_home\.gemrc"
    echo "=> generating: $fprc"
    Remove-Item $fprc -Force
    echo "---"                      | out-file -filePath $fprc -encoding ASCII
    echo ":backtrace: false"        | out-file -filePath $fprc -encoding ASCII -Append
    echo ":bulk_threshold: 1000"    | out-file -filePath $fprc -encoding ASCII -Append
    echo ":sources:"                | out-file -filePath $fprc -encoding ASCII -Append
    echo "- http://rubygems.org"    | out-file -filePath $fprc -encoding ASCII -Append
    echo ":update_sources: true"    | out-file -filePath $fprc -encoding ASCII -Append
    echo ":verbose: true"           | out-file -filePath $fprc -encoding ASCII -Append
    #return


    gem update --system 2.3.0

    gem_install -pkg "erubis"
    gem_install -pkg "cucumber" -ver "1.3.18"
    gem_install -pkg "calabash"
    gem_install -pkg "calabash-android"

    reload_env
}





#########################
# prepare installed tools
#   visual studio
#   java7
#   android sdk
#   android ndk
#########################

reload_env

check_env
check_ant
check_cygwin

check_tools
check_ssh
check_python
check_ruby

check_calabash

check_logoff

exit 0
