# Installation basique d'un Win11 Pro
# PC de Travail :       baine\baine         192.168.0.177               9..
# PC hôte des VMs :     bainevm\baine_vm    192.168.0.180               9..
# VM WinServer2025 :    home\administrator  192.168.0.185   home.lan    Pa$$w0rd

# Importation sur l'hôte du script de configuration de la VM WinServer2025
scp `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\0.1_LABSP_Create.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\0.2_LABSP_Config.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\0.3_ConfigLangueAffichage.ps1" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\Config_VM.csv" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\Create_VM.csv" `
    "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Client\ConfigLangueAffichage.json" `
    baine_vm@192.168.0.180:/C:/Users/baine_vm/Desktop/Temp/

ssh baine_vm@192.168.0.180
Set-Location Desktop/Temp/
powershell.exe 
powershell.exe -ExecutionPolicy Bypass ./0.1_LABSP_Create.ps1
powershell.exe -ExecutionPolicy Bypass ./0.2_LABSP_Config.ps1
powershell.exe -ExecutionPolicy Bypass ./0.3_ConfigLangueAffichage.ps1
    

# Importation sur le client (WinServer2025) du script de configuration des VMs
    Set-Location C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Host
scp `
".\1.1_ConfigLangueAffichage.ps1" `
".\1.2_ConfigLangueAffichage.json" `
".\1.4.1_Create_Users.ps1" `
".\1.4.2_utilisateurs.csv" `
".\1.8_Desactivation_de_compte.ps1" `
".\1.9_Merge_Rapports.ps1" `
Administrator@192.168.0.185:/C:/Users/Administrator/Desktop/Temp/

Set-Location Desktop/Temp/
powershell.exe -ExecutionPolicy Bypass ./1.1_ConfigLangueAffichage.ps1
powershell.exe -ExecutionPolicy Bypass ./1.4.1_Create_Users.ps1
powershell.exe -ExecutionPolicy Bypass -File "./1.8_Desactivation_de_compte.ps1"
powershell.exe -ExecutionPolicy Bypass -File "./1.9_Merge_Rapports.ps1"