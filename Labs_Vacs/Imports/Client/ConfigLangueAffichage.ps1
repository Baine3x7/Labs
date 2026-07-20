<#
    Exporte ou importe la configuration de langue d'affichage Windows
    (langue d'affichage UI, locale systeme, localisation geographique).
    A executer en tant qu'administrateur.

    Exemples :
      .\ConfigLangueAffichage.ps1 -Mode Export
      .\ConfigLangueAffichage.ps1 -Mode Import

    Un redemarrage (ou deconnexion/reconnexion) peut etre necessaire
    apres un import pour que le changement soit pleinement applique.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Export", "Import")]
    [string]$Mode,

    [string]$Chemin = (Join-Path $PSScriptRoot "ConfigLangueAffichage.json")
)

if ($Mode -eq "Export") {
    $config = [PSCustomObject]@{
        UILanguageOverride = (Get-WinUILanguageOverride).Name
        SystemLocale       = (Get-WinSystemLocale).Name
        HomeLocationGeoId  = (Get-WinHomeLocation).GeoId
    }

    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $Chemin -Encoding utf8

    Write-Host "Configuration de langue d'affichage exportee vers : $Chemin" -ForegroundColor Green
    $config
}
else {
    if (-not (Test-Path $Chemin)) {
        Write-Error "Fichier de configuration introuvable : $Chemin"
        exit 1
    }

    $config = Get-Content -Path $Chemin -Raw | ConvertFrom-Json

    if ($config.UILanguageOverride) {
        Set-WinUILanguageOverride -Language $config.UILanguageOverride
    }

    if ($config.SystemLocale) {
        Set-WinSystemLocale -SystemLocale $config.SystemLocale
    }

    if ($config.HomeLocationGeoId) {
        Set-WinHomeLocation -GeoId $config.HomeLocationGeoId
    }

    Write-Host "Configuration de langue d'affichage importee. Un redemarrage est recommande." -ForegroundColor Green
}
