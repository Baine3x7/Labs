# Installation basique d'un Win11 Pro

# Configuration réseau en IP fixe dans le but d'acceder en SSH
# Sur l'hôte
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.0.170 -PrefixLength 24 -DefaultGateway 192.168.0.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8
Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6
# Sur l'hote + PC de travail
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'  #Check Si le service est installé
Add-WindowsCapability -Online -Name OpenSSH.server~~~~0.0.1.0.      #Installe le service SSH
Start-Service sshd                                                  #Demarre le service SSH
Set-Service -Name sshd -StartupType 'Automatic'                     #Configure pour que le service SSH démarre toujours au démarrage
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 # Crée une règle de la parefeu pour le port 22 (SSH)



# Installation avec Winget + Features + Tweaking
winget search Microsoft.VisualStudioCode
winget install Microsoft.VisualStudioCode

winget search --name github
winget install --id Git.Git -e --source winget
winget install GitHub.GitHubDesktop

irm https://christitus.com/win | iex
