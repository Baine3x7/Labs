# 1. Installer le rôle WDS via PowerShell (Install-WindowsFeature WDS -IncludeManagementTools) et l'initialiser avec wdsutil ou le module WDS.
Install-WindowsFeature WDS -IncludeManagementTools
wdsutil /Initialize-Server /RemInst:"E:\RemoteInstall" 

# 2. Ajouter une image de démarrage (boot.wim) et une image d'installation (install.wim) à partir d'un ISO Windows monté avec Mount-DiskImage.
# Sert à monter l'ISO Windows pour accéder aux fichiers nécessaires à l'ajout des images de démarrage et d'installation.
# Inutile sur Hyper-V car on peut directement accéder aux fichiers de l'ISO vu que l'ISO est déjà monté sur un lecteur virtuel dans la machine virtuelle. 
# Cependant, si vous utilisez un serveur physique ou un autre environnement, vous devrez monter l'ISO pour accéder aux fichiers.
Mount-DiskImage -ImagePath "C:\Path\To\Windows.iso"

# Récupérer la lettre de lecteur attribuée au montage
$DriveLetter = (Get-DiskImage -ImagePath "C:\Path\To\Windows.iso" | Get-Volume).DriveLetter

# Dans le cas de la VM
$DriveLetter = "E"  # Remplacez par la lettre de lecteur appropriée si nécessaire

# Ajouter l'image de démarrage (boot.wim, dans sources\)
Import-WdsBootImage -Path "$($DriveLetter):\sources\boot.wim" -NewImageName "Boot Image"

# Ajouter l'image d'installation (install.wim), avec un nom de groupe d'images
Import-WdsInstallImage -Path "$($DriveLetter):\sources\install.wim" -NewImageGroupName "MonGroupe"

# Démonter l'ISO une fois les images ajoutées
Dismount-DiskImage -ImagePath "C:\Path\To\Windows.iso"