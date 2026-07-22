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
    Set-Location C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Host
    scp `
        ".\1.1_ConfigLangueAffichage.ps1" `     # Configuration Langue + Clavier du PC
        ".\1.2_ConfigLangueAffichage.json" `    # Fichier de configuration exporté
        ".\1.4.1_Create_Users.ps1" `            # Création des utilisateurs et groupes à partir d'un fichier CSV
        ".\1.4.2_utilisateurs.csv" `            # Fichier CSV contenant les informations des utilisateurs à créer
        ".\1.8_Desactivation_de_compte.ps1" `   # Désactivation des comptes inactifs depuis un certain nombre de jours
        "./1.9_Merge_Rapports.ps1" `            # Fusion des rapports générés par les scripts précédents
        Administrator@192.168.0.185:/C:/Users/Administrator/Desktop/Temp/

    Set-Location Desktop/Temp/
    New-Item -Path ".\Rapports" -ItemType Directory -Force #Obligatoire pour que le script 1.9_Merge_Rapports.ps1 fonctionne correctement
    powershell.exe -ExecutionPolicy Bypass ./1.1_ConfigLangueAffichage.ps1
    powershell.exe -ExecutionPolicy Bypass ./1.4.1_Create_Users.ps1
    powershell.exe -ExecutionPolicy Bypass -File "./1.8_Desactivation_de_compte.ps1"
    powershell.exe -ExecutionPolicy Bypass -File "./1.9_Merge_Rapports.ps1"





