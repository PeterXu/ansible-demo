
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

function check_env 
{
    $env_home = "$env:UserProfile"

    if ($env:Home -ne $env_home) {
        set_env "HOME" "$env_home"
    }
}

function check_ant 
{
    $ant_home = "C:\Tools\apache-ant-1.9.4"

    set_path "$ant_home\bin"
    if ($env:ANT_HOME -ne $ant_home) {
        set_env "ANT_HOME" "$ant_home"
    }
}

function check_cygwin
{
    $cyg_ps = "C:\ProgramData\chocolatey\lib\cyg-get\tools\cyg-get.ps1"

    set_path "$cyg_home"
    set_path "$cyg_home\bin"

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
        rm -f get-pip.py
        $pip = "https://bootstrap.pypa.io/get-pip.py"
        wget $pip
        python get_pip.py

        $cmdfile = "$cyg_home\bin\pip.bat" 
        echo "python /usr/bin/pip %*" | out-file -filePath $cmdfile -encoding ASCII
    }
}

function check_python
{
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
    set_path "C:\Tools\ruby215\"
    set_path "C:\Tools\ruby215\bin"

    set_path "C:\tools\DevKit2"
    set_path "C:\tools\DevKit2\bin"
    Push-Location
    cd "C:\tools\DevKit2"
    ruby dk.rb init
    ruby dk.rb install
    Pop-Location
}

function check_calabash
{
    #gem sources -r https://rubygems.org/
    #gem sources -a http://rubygems.org/

    $fprc="$env:HOME\.gemrc"
    echo "=> generating: $fprc"
    rm -f $fprc
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
}




#########################
# prepare installed tools
#   visual studio
#   java7
#   android sdk
#   android ndk
#########################


$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$cyg_home = "C:\Tools\cygwin"

check_env
check_ant
check_cygwin
check_tools

check_python
check_ruby
check_calabash

exit 0
