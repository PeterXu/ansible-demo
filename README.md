For Windows
-----------

    http://www.simlinux.com/books/Ansible-notes.pdf

    Set-ExecutionPolicy RemoteSigned
    Set-ExecutionPolicy Unrestricted
    Set-ExecutionPolicy -Scope "CurrentUser" -ExecutionPolicy "Unrestricted"
    https://raw.githubusercontent.com/cchurch/ansible/devel/examples/scripts/upgrade_to_ps3.ps1
    https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1

### For pywinrm
pip install http://github.com/diyan/pywinrm/archive/master.zip#egg=pywinrm
pip install kerberos

### For winrm service

winrm enumerate winrm/config/listener
winrm quickconfig
winrm e winrm/config/listener
