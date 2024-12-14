# Setting up SSH Server on Windows

## Side note (Valid as of 12/11/2024)
Quite tedious process. Making some notes here.

## Installation of OpenSSH (Valid as of 12/11/2024)
1. Go to `Settings > System > Optional features`
2. If not found in added features, click on `Add a feature` and search for your feature.
3. If `reboot` is required, restart your PC

## Setting up your OpenSSH Server
1. Run `Powershell` as Admin
2. Run `Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'`
3. Run `Set-Service sshd -StartupType Automatic` Or `Set-Service sshd -StartupType Manual` to just get the service's StartupType out of `disabled` 
4. Run `Start-Service sshd` to start your Open SSH Server. It will create a `sshd_config` file in your `C:\\ProgramData\ssh`.

## Configure your OpenSSH Server (Important)
1. After running `Start-Service sshd`, it will create a `sshd_config` file in your `C:\\ProgramData\ssh`.
2. You can modify the content in `sshd_config`. Most commonly, we can change the following:
    1. `Port <port num>` -> Allow you to choose whichever port you want your server to run on. Default: 22
    2. `PasswordAuthentication yes` -> Enable/Disable Password Login. Default: yes
    3. `PubkeyAuthentication no` -> Enable/Disable RSA Key Login. Default: no
    4. `AuthorizedKeysFile <path>` -> Allow you to choose which path to search under every user for Authorized RSA keys
3. After modification of `sshd_config`, run `Restart-Service sshd` to allow the changes to take places
4. Go to `Window Firewall > Advanced settings` as we need to enable packets to the OpenSSH port to be able to reach the server.
5. Click on `Inbound Rules > New Rule > Port > TCP`
6. Enter the `Port num` you chose in `sshd_config`, then click next all the way until you give a name for this rule and save it.

## How to connect to your OpenSSH Server from another computer?
1. Basically, you need to check your OpenSSH Server IP. 
    1. If your client is connected to the same local network as your server, run `ipconfig` on your server'command prompt and get the IPV4. 
    2. Else, you need to get the public IP (This will cost money). You can modify your WAN's port forwarding if your router allows OR you can buy a VPN for your server to get a public IP.
2. On the client PC, simply run `ssh <your open sshserver account name>@<your open ssh server IP> -p <your open ssh config port number>`
3. By default, it should prompt you for password.

## How to configure your OpenSSH to use sshkey?
1. This is better than password as it is more secure and it save your effort to always type in your password.
2. Run `cd  $env:USERPROFILE` to change the working directory to your home path
3. Explain some rationale: We are making a directory `<path>` in `sshd_config` defined as `AuthorizedKeysFile <path>`
    1. By default, `<path>` would be `.ssh\authorized_keys`
    2. Note that path is a relative path from **every user's homepath** which commonly would be `C:\\Users\<youruseraccount>`
    3. Hence, if you modify this path, you **need** to make the directory accordingly from Step 4 to 7
4. Run `mkdir .ssh` if this folder `.ssh` does not exist.
5. Run `ssh-keygen` in powershell which will create a ssh key-value
6. Note that the pub file is needed in your SSH Server and the private key file (without file extension) would be needed for your ssh client.
7. In the same folder, you can remake a file named `authorized_keys` and copy the pub file content into this file.
8. Run `cd C:\\ProgramData\ssh` and open `sshd_config`
9. Comment out `Match Group administrators` and `AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys` by adding `#` at the start of each line
    1. Like this `# Match Group administrators` and `# AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys`
    2. This is important otherwise it would be bugged. Apparently, it seems to have some problem with two `AuthorizedKeysFile` line.
10. Uncomment `AuthorizedKeysFile <path>` if it is commented by removing `#` at the start of the line, to allow the OpenSSH Server to find the authorized_keys file
11. Uncomment `PubkeyAuthentication yes` and set the text to `yes` to enable the RSA key usage
12. Uncomment `PasswordAuthentication no` and set the text to `no` to disable password login.
13. Save the `sshd_config`
14. Run `Restart-Service sshd`
15. Transfer the private key file to your client PC.
16. On the client PC, modify the permissions of the private key file
    1. On macs or linux, run `chmod 600 <private key file>`
    2. On windows, go to properties of `private key file` > Security > Advanced > Disable Inheritance
17. On the client PC, run `ssh -i <path to private key file> <your open sshserver account name>@<your open ssh server IP> -p <your open ssh config port number>`
18. If you want to make the command shorter, you can add a `config` file under `<user home>/.ssh` in your user pc. 
    1. Note that you need to bind your server's IP to static IP such that it would not change very often. Otherwise, you may need to modify the `config` file very often.

## Use of `start_server.ps`
The purpose of this script is to start sshd and turning off sshd when you are done using it.  
It also helps you enable/disable the firewall rules when you are done using it.  
1. Before running it, you need to install the OpenSSH and configure `%ProgramData%/ssh/sshd_config`.  
2. Also, ensure the `sshd` service is not started. Else, run `Stop-Service sshd` in powershell as admin.  
3. For ease of usage, create a shortcut to this script and do the following:
    1. Right-click properties of the shortcut
    2. In the `target` box, add `%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -NoExit ` before the original path
    3. Go to `Advanced`, check `Run as administrator`.

