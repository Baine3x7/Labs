# Installation basique d'un Win11 Pro
# PC de Travail :       baine\baine         192.168.0.177               9..
# PC hôte des VMs :     bainevm\baine_vm    192.168.0.180               9..
# VM WinServer2025 :    home\administrator  192.168.0.185   home.lan    Pa$$w0rd

# Configuration réseau en IP fixe dans le but d'acceder en SSH
# Sur le client (WinServer2025)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.0.170 -PrefixLength 24 -DefaultGateway 192.168.0.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8
Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6
# Sur le client (WinServer2025)
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'  #Check Si le service est installé
Add-WindowsCapability -Online -Name OpenSSH.server~~~~0.0.1.0.      #Installe le service SSH
Start-Service sshd                                                  #Demarre le service SSH
Set-Service -Name sshd -StartupType 'Automatic'                     #Configure pour que le service SSH démarre toujours au démarrage
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 # Crée une règle de la parefeu pour le port 22 (SSH)

# Sur l'hôte
ssh baine_vm@192.168.0.180
password. 9..

# Installation avec Winget + Features + Tweaking
winget update --all #Mets à jour tous les packets installés
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All #Active HyperV pour le client

# Installation de l'arboresence des VMs
mkdir D:\Lab
mkdir D:\Parent

# Préconfiguration de HyperV

# En SSH
New-VMSwitch -Name "LabHome" -SwitchType Private #Crée le switch

# Sur l'hote en Powershell (Importe les fichiers sur la machine Hote)
scp `
"C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\2.11.LABSP_Create.ps1" `
"C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\2.12.Create_VM.csv" `
baine_vm@192.168.0.180:/D:/Temp/

scp `
"C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\2.21.LABSP_Config.ps1" `
"C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\2.22.Config_VM.csv" `
baine_vm@192.168.0.180:/D:/Temp/

powershell.exe -ExecutionPolicy Bypass -File D:\Temp\2.11.LABSP_Create.ps1 #Execute en bypass la sécurité de PowerShell


$cred = Get-Credential

Invoke-Command -VMName "SRV-AD" -Credential $cred -ScriptBlock {

    # Vérifie les composants OpenSSH
    Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'

    # Installation du serveur SSH
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

    # Démarrage du service
    Start-Service sshd

    # Démarrage automatique du service
    Set-Service -Name sshd -StartupType Automatic

    # Création de la règle du pare-feu
    New-NetFirewallRule `
        -Name sshd `
        -DisplayName "OpenSSH Server" `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -Action Allow `
        -LocalPort 22

}

# Se logger avec le domaine (home\Administrator) lors de la demande des credidentials

# Ensuite sur l'hôte du serveur
ssh baine_vm@192.168.0.185

# Se connecter à la VM
ssh Administrator@home.lan

## RAPPEL : GATEWAY = ADDRESSE DU MODEM MEME EN LAN

# Configuration similaire sur les pcs : 
scp `
>> "C:\Users\Baine\SynologyDrive\GitHub\Claude\ConfigPosteTravail.ps1"`
>> baine_vm@192.168.0.180:/D:/Temp/

 cd d:/Temp/
 powershell.exe -ExecutionPolicy Bypass ./ConfigPosteTravail.ps1

 # Installation des utilisateurs et des groupes: 
scp `
>> "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\1.4.1 Script + CS.ps1"
 "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\1.4.2 utilisateurs.csv" `
>> baine_vm@192.168.0.180:/D:/Temp/

 cd d:/Temp/
 powershell.exe -ExecutionPolicy Bypass ./1.4.1 Script + CS.ps1

 # Sur le pc de travail en Powershell (Importe les fichiers sur la machine Hote)
scp `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\0.11.LABSP_Create.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\0.12.Create_VM.csv" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\0.21.LABSP_Config.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\0.22.Config_VM.csv" `
    baine_vm@192.168.0.180:/C:/Users/baine_vm/Desktop/Temp/

# Lancer les scripts en SSH depuis le pc de travail
# Importation de tous les scripts sur la VM pour les utiliser en SSH
scp `
    "C:\Users\Baine\SynologyDrive\GitHub\Claude\ConfigPosteTravail.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\1.4.1_Create_Users.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\1.4.2_utilisateurs.csv" `
    Administrator@192.168.0.185:/C:/Users/Administrator/Desktop/Temp/

    
