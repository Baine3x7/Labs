<#
.SYNOPSIS
    Automatise l'ajout d'une image de démarrage (boot.wim) et d'une image d'installation
    (install.wim) dans WDS, à partir d'un fichier ISO Windows.

.DESCRIPTION
    1. Monte l'ISO fourni.
    2. Copie boot.wim et install.wim depuis l'ISO monté vers un dossier de staging local.
    3. Démonte l'ISO (on n'en a plus besoin une fois les fichiers copiés).
    4. Importe les deux images dans WDS via Import-WdsBootImage / Import-WdsInstallImage.

.PARAMETER IsoPath
    Chemin complet vers le fichier .iso Windows.

.PARAMETER StagingPath
    Dossier local où copier boot.wim et install.wim avant import.
    (WDS lit depuis un chemin de fichier classique, pas depuis l'ISO monté directement,
    donc on copie pour ne pas dépendre du montage lors de l'import ni après.)

.PARAMETER BootImageName
    Nom donné à l'image de démarrage dans WDS.

.PARAMETER ImageGroupName
    Nom du groupe d'images WDS dans lequel importer install.wim.

.EXAMPLE
    .\Import-ImagesWDS.ps1 -IsoPath "C:\ISOs\Windows11.iso" -StagingPath "D:\WDS_Staging" `
        -BootImageName "Boot Windows 11" -ImageGroupName "Win11"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [Parameter(Mandatory = $true)]
    [string]$StagingPath,

    [Parameter(Mandatory = $true)]
    [string]$BootImageName,

    [Parameter(Mandatory = $true)]
    [string]$ImageGroupName
)

$ErrorActionPreference = "Stop"

try {
    # Vérifier que le module WDS est chargé
    if (-not (Get-Module -Name WDS)) {
        Import-Module WDS -ErrorAction Stop
    }

    # Vérifier que l'ISO existe
    if (-not (Test-Path -Path $IsoPath)) {
        throw "ISO introuvable : $IsoPath"
    }

    # Créer le dossier de staging s'il n'existe pas
    if (-not (Test-Path -Path $StagingPath)) {
        New-Item -Path $StagingPath -ItemType Directory -Force | Out-Null
    }

    # 1. Monter l'ISO
    Write-Host "Montage de l'ISO : $IsoPath" -ForegroundColor Cyan
    $Image = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $DriveLetter = ($Image | Get-Volume).DriveLetter

    if (-not $DriveLetter) {
        throw "Impossible de récupérer la lettre de lecteur du montage."
    }

    $SourceBootWim    = "$($DriveLetter):\sources\boot.wim"
    $SourceInstallWim = "$($DriveLetter):\sources\install.wim"

    if (-not (Test-Path $SourceBootWim) -or -not (Test-Path $SourceInstallWim)) {
        throw "boot.wim ou install.wim introuvable dans l'ISO monté ($($DriveLetter):\sources\)."
    }

    # 2. Copier boot.wim et install.wim vers le dossier de staging
    Write-Host "Copie de boot.wim et install.wim vers $StagingPath" -ForegroundColor Cyan
    Copy-Item -Path $SourceBootWim -Destination $StagingPath -Force
    Copy-Item -Path $SourceInstallWim -Destination $StagingPath -Force

    $LocalBootWim    = Join-Path $StagingPath "boot.wim"
    $LocalInstallWim = Join-Path $StagingPath "install.wim"

    # 3. Démonter l'ISO (plus besoin, les fichiers sont copiés localement)
    Write-Host "Démontage de l'ISO" -ForegroundColor Cyan
    Dismount-DiskImage -ImagePath $IsoPath

    # 4. Importer les images dans WDS
    Write-Host "Import de l'image de démarrage dans WDS : $BootImageName" -ForegroundColor Cyan
    Import-WdsBootImage -Path $LocalBootWim -NewImageName $BootImageName

    Write-Host "Import de l'image d'installation dans WDS : groupe $ImageGroupName" -ForegroundColor Cyan
    Import-WdsInstallImage -Path $LocalInstallWim -NewImageGroupName $ImageGroupName

    Write-Host "Terminé : images importées avec succès dans WDS." -ForegroundColor Green
}
catch {
    Write-Error "Échec du script : $($_.Exception.Message)"

    # Sécurité : si l'ISO est resté monté suite à une erreur, on tente de le démonter
    if (Get-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Where-Object { $_.Attached }) {
        Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    }
}