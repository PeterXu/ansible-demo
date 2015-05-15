Param(
  [string]$target
)

if ($target) {
    echo "Process $target ..."
} else { 
    echo "usage: ps_win.ps1 target"  
    exit 0 
}


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
    reload_env
    if ($env:HOME -ne $env_home) {
        set_env "HOME" "$env_home"
    }
    set_path "$choco_home\bin"
    set_path "C:\Program Files (x86)\Windows Kits\8.1\Tools\x64"
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
    $pkgs = "nasm,curl,wget,git,openssh,p7zip,cmake"
    cyg-get "$pkgs"

    cmd /C where 7z.bat
    $ret = $?
    if (!$ret) {
        $cmdfile = "$cyg_home\bin\7z.bat" 
        echo "$cyg_home\lib\p7zip\7z.exe %*" | out-file -filePath $cmdfile -encoding ASCII
    }

    cmd /C where pip
    $ret = $?
    if (!$ret) {
        $src = "https://bootstrap.pypa.io/get-pip.py"
        $dest = "$env_home\get-pip.py"
        Remove-Item $dest -Force
        Invoke-WebRequest $src -OutFile $dest
        python $dest
    }
}

function check_ssh
{
    $id_rsa =@"
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEA1ciD4LoouaBsfOLH142gI/TuQpb1VxwDhagjJ6N/pBFLnR1J
K5gYr4RqHtj1lROn2H/yYwt4Dz5FR0UwzptHwagdAcHXgVkrxCqLeHcgQ4dtw3GR
pcCPdYfS/HxzlS5HgdWNBMvFmmly2IJ58hiJrPOOJ7BvGndu09an1mRqlZ3jravK
ILQAjMWy2yLXVkkexZmzBdg/Xzxs6R2Yk6ITQ/P2kTebq73oD5G/w209KX8qwhO0
I2KOsVRN9nQOXSSW6hQKFtkSKuXGm7dutrr26syFi4crDGMHL7ZrvwY8eP5WSo1R
OIlSqFJOvg4eBYXhk6sx8ansGKH7QFcE+TZcjQIDAQABAoIBAQC76y5BdGIoCaRT
guU3zP5fnQVy809l6vINouaECWxBxBI7YWrYLzJD1pmR1BTLniOEY7Ok7If0nkA3
jdKBSm2hBS26RbIxuTiHjv5aPhzWP01053enw8RXA7Wqy5quH6grsJPtC1H/kYGq
X8bh0D/1D4J90NFY6nM5Mw8Fne8y46OYZljbOplVIfCc7XKU5KotvYjvm2sw08jL
ff89XpefuQoMnwwv7KLiRx3ohPtEaC8/pB6nbFulbtJ1pyMAydAcgUNnmAqMsehM
7vTuPXvuVdUjHmfVUu7t057svFZWHhjnu4hhsH42ci4gWdZk45Z90vCjbQcXqq/k
5hX/xNsBAoGBAPKpe9s1uvsL8DE7tgkPlBH3DAlrF7rLZYvzUyXXN8mnXk4VSoXg
RJw+jVyJpRpOvHTsfJtvp0l528RSnZXzNoGB/6QgB9T4EtLlbsG+/BfUjGwAajVR
FY6bR8gcmbBrkSeWg86zaydA8mh2k+uxs8Cab1KY/aCGQCH9AvolJ1m5AoGBAOGI
rP6o54KkgyVEbI8gvhWBjVAZymN2BFc9gHSIu/Xu2IVe10DjATGVvtBwVtHK/w8a
S2qznIp/M3aZu/t0Ja5IHRKzZeb3nMlFDvf99MrFQhxZAa3wOaaCAXEvwj73waex
ERTk7EHFFZQTLrprvNGnY9aSmGlFcVnHw2jVbrN1AoGAFmEDByhhYh2rvR6gnx1M
rot2FLhHq/ZuGwYJuQesIXDKBbF4+ffA3Bf4uXwIOfDg+HeG1l7psqEGX4iu99FC
SZdPmDdMAZwPQFvgZwXSAfCcMqmnIdukfU5cxFu+4MJK1LfQ2BM74pbexDuLUMVG
qpCTi66IVXGMIJZQ2/jpNCECgYEAyVIcwpH5XqgFnU2v7i+XHlFv2FG9VP1zMIDo
2p130zeqtZsMYJKCbUWzeBLfnRQsi8m4Cn5cPVEAmlzu7a4nOKSMtzXGv97GaO+p
Rfu++QYOVompMyAeBiFEskmkhlrY1hz8F3+l2avY8D4TVzt26FsYhuCDBm2DmlX0
e+8Ri0UCgYEAjvQn1tJjoZuRbBfRaEitP6UCFPokdDCn1wXDmT9pod3320INGmJa
Xhet1sN6qkMbRYRAsLteABF4BFWNrqDcntcpX5prWGnZkQMr0T+7QilX6JuA46WZ
TE7JcpI1RZqI4sf52QIDvppHkdZEIgFmf3STROrvfdbQxKY5ZTuDC2w=
-----END RSA PRIVATE KEY-----
"@
    $id_rsa_pub = @"
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVyIPguii5oGx84sfXjaAj9O5ClvVXHAOFqCMno3+kEUudHUkrmBivhGoe2PWVE6fYf/JjC3gPPkVHRTDOm0fBqB0BwdeBWSvEKot4dyBDh23DcZGlwI91h9L8fHOVLkeB1Y0Ey8WaaXLYgnnyGIms844nsG8ad27T1qfWZGqVneOtq8ogtACMxbLbItdWSR7FmbMF2D9fPGzpHZiTohND8/aRN5urvegPkb/DbT0pfyrCE7QjYo6xVE32dA5dJJbqFAoW2RIq5cabt262uvbqzIWLhysMYwcvtmu/Bjx4/lZKjVE4iVKoUk6+Dh4FheGTqzHxqewYoftAVwT5NlyN jenkins@whsus-iMac.local
"@

    ################################################
    # Set windows id_rsa
    $ssh_path = "$env_home\.ssh"
    cmd /C $cyg_home\bin\mkdir -p $ssh_path
    echo $id_rsa        | out-file -filePath "$ssh_path\id_rsa" -encoding ASCII
    echo $id_rsa_pub    | out-file -filePath "$ssh_path\id_rsa.pub" -encoding ASCII


    ################################################
    # Set SSHD service
    $ssh_name = "testbed"
    $ssh_pass = "wme@cisco"

    # remove sshd service
    cmd /C "cygrunsrv -L | grep sshd && cgyrunsrv -R sshd"
    cmd /C "rm -rf /home/testbed"

    # set firewall
    $name = "sshd"
    $sshd = "$cyg_home\usr\sbin\sshd.exe"
    netsh advfirewall firewall delete rule name="$name"
    netsh advfirewall firewall add rule name="$name" dir=in action=allow program="$sshd" protocol=UDP profile=any enable=yes
    netsh advfirewall firewall add rule name="$name" dir=in action=allow program="$sshd" protocol=TCP profile=any enable=yes

    # stop sshd
    $cmdstr = "ps | grep sshd | awk -F `" `" '{print `$1}'"
    $sshpid = cmd /C $cmdstr
    if ($sshpid -and $sshpid -gt 0) {
        cmd /C kill -9 $sshpid
    }

    # set sshd id_rsa
    $ssh_path2 = "$cyg_home\home\$ssh_name\.ssh"
    cmd /C $cyg_home\bin\mkdir -p $ssh_path2
    echo $id_rsa        | out-file -filePath "$ssh_path2\id_rsa" -encoding ASCII
    echo $id_rsa_pub    | out-file -filePath "$ssh_path2\id_rsa.pub" -encoding ASCII
    cmd /C chmod 600 "$ssh_path2/id_rsa"

    #choco uninstall freeSSHD -y
    choco install freeSSHD -y
    return

    # start sshd
    cmd /C $cyg_home\bin\bash.exe /usr/bin/ssh-host-config -y -u $ssh_name -w $ssh_pass
    cmd /C "run /usr/sbin/sshd"
}

function check_python
{
    set_path "$tool_home\python2"
    set_path "$tool_home\python2\Scripts"

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
    # set firewall rule
    $name = "Ruby"
    $ruby = "$tool_home\ruby215\bin\ruby.exe"
    netsh advfirewall firewall delete rule name="$name"
    netsh advfirewall firewall add rule name="$name" dir=in action=allow program="$ruby" protocol=UDP profile=any enable=yes
    netsh advfirewall firewall add rule name="$name" dir=in action=allow program="$ruby" protocol=TCP profile=any enable=yes


    set_path "$tool_home\ruby215"
    set_path "$tool_home\ruby215\bin"
    reload_env

    set_path "$tool_home\DevKit2"
    set_path "$tool_home\DevKit2\bin"
    reload_env

    Push-Location
    cd "$tool_home\DevKit2"
    ruby dk.rb init
    #sed -i 's#C:/Ruby193#C:\Tools\ruby215#' config.yml
    echo "---" | out-file -filePath config.yml -encoding ASCII
    echo " - C:\Tools\ruby215" | out-file -filePath config.yml -encoding ASCII -Append
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

# Start powershell as Administrator
#Start-Process PowerShell –Verb RunAs


check_env

$tasks = @("ant", "cygwin", "tools", "ssh", "python", "ruby", "calabash")
ForEach ($task In $tasks) {
    if ($target -eq $task -or $target -eq "all") {
        $func = "check_$task"
        if (Get-Command $func -errorAction SilentlyContinue) {
            & $func
        }
    } 
}

#check_logoff

exit 0
