#Installation du service WDS sur Windows Server
#Ce script installe le rôle WDS sur un serveur Windows Server et configure les paramètres de base
Add-WindowsFeature -Name WDS -IncludeManagementTools
Set-Service -Name WDS -StartupType Automatic
Start-Service -Name WDS

# Installation des images d'installation et de démarrage dans WDS
New-WdsInstallImageGroup -Name "Windows 11" | Out-Null
Import-WdsBootImage -Path "E:\WDS_Staging\boot.wim" -NewImageName "Boot Windows 11"
Import-WdsInstallImage -Path "E:\WDS_Staging\install.wim" -ImageGroup "Windows 11" -Imagename "Windows 11"
