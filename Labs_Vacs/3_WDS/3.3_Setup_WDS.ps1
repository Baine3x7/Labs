<#
.SYNOPSIS
    Installe et configure le rôle WDS sur Windows Server, puis importe les images
    de démarrage et d'installation préalablement copiées en staging.

.DESCRIPTION
    1. Installe le rôle WDS (si pas déjà présent) et ses outils d'administration.
    2. Configure le service WDS en démarrage automatique et le démarre.
    3. Initialise le serveur WDS (dossier RemoteInstall) si ce n'est pas déjà fait.
    4. Crée le groupe d'images d'installation (s'il n'existe pas déjà).
    5. Importe l'image de démarrage (boot.wim).
    6. Importe l'image d'installation (install.wim), pour l'édition Windows précisée.

    Le script est idempotent : si le rôle est déjà installé, le serveur déjà initialisé,
    le groupe déjà créé ou l'image déjà importée, l'étape correspondante est simplement
    ignorée au lieu de provoquer une erreur.

.PARAMETER RemoteInstallPath
    Dossier où WDS stockera ses images (créé lors de l'initialisation du serveur).

.PARAMETER StagingPath
    Dossier local contenant déjà boot.wim et install.wim (copiés au préalable).

.PARAMETER BootImageName
    Nom donné à l'image de démarrage dans WDS.

.PARAMETER ImageGroupName
    Nom du groupe d'images WDS dans lequel importer install.wim.

.PARAMETER ImageName
    Nom exact de l'édition Windows à importer depuis install.wim (ex: "Windows 11 Pro").
    Si non fourni, le script liste les éditions disponibles et demande laquelle importer.

.EXAMPLE
    .\Install-ConfigWDS.ps1 -RemoteInstallPath "E:\RemoteInstall" -StagingPath "E:\WDS_Staging" `
        -BootImageName "Boot Windows 11" -ImageGroupName "Windows 11" -ImageName "Windows 11 Pro"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Dossier ou WDS stockera ses images (ex: E:\RemoteInstall)")]
    [string]$RemoteInstallPath,

    [Parameter(Mandatory = $false, HelpMessage = "Dossier local contenant deja boot.wim et install.wim (ex: E:\WDS_Staging)")]
    [string]$StagingPath,

    [Parameter(Mandatory = $false, HelpMessage = "Nom affiche dans WDS pour l'image de demarrage")]
    [string]$BootImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Nom du groupe d'images WDS dans lequel install.wim sera range")]
    [string]$ImageGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Nom exact de l'edition Windows a importer depuis install.wim. Laisser vide pour choisir dans une liste.")]
    [string]$ImageName
)

$ErrorActionPreference = "Stop"

### ============================================================
### Demande interactive des valeurs manquantes, avec explication
### ============================================================
if ([string]::IsNullOrWhiteSpace($RemoteInstallPath))
{
    Write-Host ""
    Write-Host "RemoteInstallPath - Dossier ou WDS va stocker ses images (cree lors de l'initialisation)." -ForegroundColor DarkGray
    Write-Host "                    Exemple : E:\RemoteInstall" -ForegroundColor DarkGray
    $RemoteInstallPath = Read-Host "Dossier RemoteInstall"
}

if ([string]::IsNullOrWhiteSpace($StagingPath))
{
    Write-Host ""
    Write-Host "StagingPath - Dossier local ou boot.wim et install.wim ont deja ete copies." -ForegroundColor DarkGray
    Write-Host "              Exemple : E:\WDS_Staging" -ForegroundColor DarkGray
    $StagingPath = Read-Host "Dossier de staging"
}

if ([string]::IsNullOrWhiteSpace($BootImageName))
{
    Write-Host ""
    Write-Host "BootImageName - Nom qui sera affiche dans WDS pour l'image de demarrage." -ForegroundColor DarkGray
    Write-Host "                Exemple : Boot Windows 11" -ForegroundColor DarkGray
    $BootImageName = Read-Host "Nom de l'image de demarrage"
}

if ([string]::IsNullOrWhiteSpace($ImageGroupName))
{
    Write-Host ""
    Write-Host "ImageGroupName - Nom du groupe d'images WDS dans lequel install.wim sera range." -ForegroundColor DarkGray
    Write-Host "                 Exemple : Windows 11" -ForegroundColor DarkGray
    $ImageGroupName = Read-Host "Nom du groupe d'images"
}

try {
    ### 1. Installation du role WDS
    $Feature = Get-WindowsFeature -Name WDS
    if ($Feature.Installed)
    {
        Write-Host "Le role WDS est deja installe, etape ignoree." -ForegroundColor Yellow
    }
    else
    {
        Write-Host "Installation du role WDS..." -ForegroundColor Cyan
        Add-WindowsFeature -Name WDS -IncludeManagementTools | Out-Null
    }

    ### 2. Configuration du service WDS
    Write-Host "Configuration du service WDS (demarrage automatique)..." -ForegroundColor Cyan
    Set-Service -Name WDS -StartupType Automatic
    Start-Service -Name WDS -ErrorAction SilentlyContinue

    if (-not (Get-Module -Name WDS)) {
        Import-Module WDS -ErrorAction Stop
    }

    ### 3. Initialisation du serveur WDS (dossier RemoteInstall) si pas deja fait
    if (Test-Path $RemoteInstallPath)
    {
        Write-Host "Le serveur WDS semble deja initialise ($RemoteInstallPath existe), etape ignoree." -ForegroundColor Yellow
    }
    else
    {
        Write-Host "Initialisation du serveur WDS : $RemoteInstallPath" -ForegroundColor Cyan
        wdsutil /Initialize-Server /RemInst:"$RemoteInstallPath" | Out-Null
    }

    ### 4. Verification des fichiers en staging
    $LocalBootWim    = Join-Path $StagingPath "boot.wim"
    $LocalInstallWim = Join-Path $StagingPath "install.wim"

    if (-not (Test-Path $LocalBootWim) -or -not (Test-Path $LocalInstallWim)) {
        throw "boot.wim ou install.wim introuvable dans $StagingPath."
    }

    ### 5. Creation du groupe d'images (s'il n'existe pas deja)
    if (Get-WdsInstallImageGroup -Name $ImageGroupName -ErrorAction SilentlyContinue)
    {
        Write-Host "Le groupe d'images '$ImageGroupName' existe deja, etape ignoree." -ForegroundColor Yellow
    }
    else
    {
        Write-Host "Creation du groupe d'images WDS : $ImageGroupName" -ForegroundColor Cyan
        New-WdsInstallImageGroup -Name $ImageGroupName | Out-Null
    }

    ### 6. Import de l'image de demarrage (si pas deja presente sous ce nom)
    if (Get-WdsBootImage -ImageName $BootImageName -ErrorAction SilentlyContinue)
    {
        Write-Host "L'image de demarrage '$BootImageName' est deja importee, etape ignoree." -ForegroundColor Yellow
    }
    else
    {
        Write-Host "Import de l'image de demarrage : $BootImageName" -ForegroundColor Cyan
        Import-WdsBootImage -Path $LocalBootWim -NewImageName $BootImageName
    }

    ### 7. Si aucune edition n'a ete precisee, lister celles presentes dans install.wim
    if ([string]::IsNullOrWhiteSpace($ImageName))
    {
        Write-Host ""
        Write-Host "Editions disponibles dans install.wim :" -ForegroundColor DarkGray
        $Editions = Get-WindowsImage -ImagePath $LocalInstallWim
        $Editions | ForEach-Object { Write-Host "  [$($_.ImageIndex)] $($_.ImageName)" -ForegroundColor DarkGray }
        Write-Host ""
        $ImageName = Read-Host "Nom exact de l'edition a importer (copier-coller depuis la liste ci-dessus)"
    }

    ### 8. Import de l'image d'installation (si pas deja presente dans ce groupe)
    if (Get-WdsInstallImage -ImageGroup $ImageGroupName -ImageName $ImageName -ErrorAction SilentlyContinue)
    {
        Write-Host "L'image d'installation '$ImageName' est deja presente dans le groupe '$ImageGroupName', etape ignoree." -ForegroundColor Yellow
    }
    else
    {
        Write-Host "Import de l'image d'installation : $ImageName (groupe $ImageGroupName)" -ForegroundColor Cyan
        Import-WdsInstallImage -Path $LocalInstallWim -ImageGroup $ImageGroupName -ImageName $ImageName
    }

    Write-Host "Terminé : role WDS installe/configure et images importees avec succes." -ForegroundColor Green
}
catch {
    Write-Error "Échec du script : $($_.Exception.Message)"
}