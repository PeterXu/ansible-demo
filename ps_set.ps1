# set privillege

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

