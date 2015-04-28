For Windows
-----------

    http://www.simlinux.com/books/Ansible-notes.pdf

### Run cmd/scripts in powershell
    Set-ExecutionPolicy RemoteSigned
    Set-ExecutionPolicy Unrestricted
    Set-ExecutionPolicy -Scope "CurrentUser" -ExecutionPolicy "Unrestricted"
    .\upgrade_to_ps3.ps1
        => https://raw.githubusercontent.com/cchurch/ansible/devel/examples/scripts/upgrade_to_ps3.ps1
    .\ConfigureRemotingForAnsible.ps1
        => https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1

### For winrm service
    winrm enumerate winrm/config/listener
    winrm quickconfig
    winrm e winrm/config/listener

### For choco sources(default)
    choco install pkg -source=https://chocolatey.org/api/v2/
    And also we can custom our sources by jnuget/...

### For choco install/uninstall
    choco install ant
    cinst cmake
    cuninst ant
    choco uninstall ant



For Nix
-------

### Set env
    sh install.sh

### Config Hosts
    Add new hosts into file of "hosts".

### Check Mac slaves
    ansible-playbook mac.yml

### Check Win slaves
    ansible-playbook win.yml


