Documents For Ansible Setting
=============================

    Refer: http://www.simlinux.com/books/Ansible-notes.pdf


1. How For Windows Remote
-------------------------

### Run cmd/scripts in powershell
    a. Run "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" as Administrator

    b. Set-ExecutionPolicy -Scope "CurrentUser" -ExecutionPolicy "Unrestricted"

    c. upgrade_to_ps3.ps1(you can get it from)
        => ps1/upgrade_to_ps3.ps1
        => https://raw.githubusercontent.com/cchurch/ansible/devel/examples/scripts/upgrade_to_ps3.ps1

    d. config winrm
        $> winrm quickconfig
        $> winrm e winrm/config/listener

    e. ConfigureRemotingForAnsible.ps1 (you can get it from)
        => ps1/ConfigureRemotingForAnsible.ps1
        => https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1

    f. Set read-write permissions for testbed by command or set manually
        $Acl = Get-Acl "C:\ProgramData"
        Set-Acl "C:\Program Files" $Acl
        Set-Acl "C:\Program Files (x86)" $Acl



2. How For Mac Remote
---------------------

### Prepare remote machine
    a. Create user "jenkins" with sudo without password (by visudo)
    b. Install sshd and Start it 



3. How For Mac Local
--------------------

### Set env in local machine
    sh install.sh

### Config Hosts in local
    Add new hosts into file of "hosts".

### Check Mac slaves over ssh
    a. The first time: 
        ansible-playbook -k mac.yml (which will need you input ssh password)

    b. Next time:
        ansible-playbook mac.yml

### Check Win slaves over winrm
    ansible-playbook win.yml


