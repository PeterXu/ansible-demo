# set privillege
$env_home = "$env:UserProfile"

$rd = Get-Random
$fprc = "test_$rd.txt"

if (Test-Path $fprc) { Remove-Item $fprc }
echo "---" | Out-File -filePath $fprc -encoding ASCII
$acl = Get-Acl $fprc

$choco = "C:\ProgramData\chocolatey"
if (Test-Path "$choco") {
    Set-Acl $choco $acl
}

$tools = "C:\Tools"
if (Test-Path "$tools") {
    Set-Acl $tools $acl
}


$client = New-Object System.Net.WebClient
$url = "http://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi"
$dest = "$env_home\VCForPython27.msi"
Try {
    if (Test-Path $dest) {
    }else {
        $client.DownloadFile($url, $dest)
    }

    if (Test-Path $dest) {
        $logfile = [IO.Path]::GetTempFileName()
        $extra_args = ""
        msiexec.exe /i $dest /qb /l $logfile $extra_args;
    }
}Catch {
}

