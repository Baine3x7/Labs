# Installation basique d'un Win11 Pro
# PC de Travail :       baine\baine         192.168.0.177               9..
# PC hôte des VMs :     bainevm\baine_vm    192.168.0.180               9..
# VM WinServer2025 :    home\administrator  192.168.0.185   home.lan    Pa$$w0rd

# Importation sur l'hôte du script de configuration de la VM WinServer2025
scp `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\ConfigLangueAffichage.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\0.11.LABSP_Create.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\0.12.Create_VM.csv" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\0.21.LABSP_Config.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\0.22.Config_VM.csv" `
    baine_vm@192.168.0.180:/D:/Temp/


# Importation sur le client (WinServer2025) du script de configuration des VMs
scp `
    "C:\Users\Baine\SynologyDrive\GitHub\Claude\ConfigPosteTravail.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\1.4.1_Create_Users.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\1.4.2_utilisateurs.csv" `
    Administrator@192.168.0.185:/C:/Users/Administrator/Desktop/Temp/




