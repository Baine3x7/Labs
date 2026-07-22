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

# --- Rapport texte horodaté (le dossier .\Rapports doit deja exister) ---
$Horodatage       = Get-Date -Format "yyyyMMdd_HHmmss"
$CheminRapportTxt = ".\1.1_rapport_langue_$($Mode)_$Horodatage.txt"

function Write-Log {
    param([string]$Message)
    $Ligne = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $CheminRapportTxt -Value $Ligne -Encoding UTF8
}

Write-Log "=== Debut du script de configuration de langue (mode : $Mode) ==="

if ($Mode -eq "Export") {
    $config = [PSCustomObject]@{
        UILanguageOverride = (Get-WinUILanguageOverride).Name
        SystemLocale       = (Get-WinSystemLocale).Name
        HomeLocationGeoId  = (Get-WinHomeLocation).GeoId
        # Dispositions de clavier associees a chaque langue installee
        LanguageList       = @(Get-WinUserLanguageList | ForEach-Object {
            [PSCustomObject]@{
                LanguageTag     = $_.LanguageTag
                InputMethodTips = @($_.InputMethodTips)
            }
        })
        # Fuseau horaire (ex : "Romance Standard Time" pour Bruxelles/Belgique)
        TimeZoneId          = (Get-TimeZone).Id
    }

    $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $Chemin -Encoding utf8

    Write-Host "Configuration de langue d'affichage exportee vers : $Chemin" -ForegroundColor Green
    Write-Log "Configuration exportee vers : $Chemin"
    Write-Log "  UILanguageOverride : $($config.UILanguageOverride)"
    Write-Log "  SystemLocale : $($config.SystemLocale)"
    Write-Log "  TimeZoneId : $($config.TimeZoneId)"
    Write-Log "  Langues : $(($config.LanguageList | ForEach-Object { $_.LanguageTag }) -join ', ')"
    Write-Log "=== Fin du script - export termine avec succes ==="
    $config
}
else {
    if (-not (Test-Path $Chemin)) {
        Write-Error "Fichier de configuration introuvable : $Chemin"
        Write-Log "ERREUR - Fichier de configuration introuvable : $Chemin"
        exit 1
    }

    $config = Get-Content -Path $Chemin -Raw | ConvertFrom-Json
    Write-Log "Configuration lue depuis : $Chemin"

    if ($config.UILanguageOverride) {
        Set-WinUILanguageOverride -Language $config.UILanguageOverride
        Write-Log "UILanguageOverride applique : $($config.UILanguageOverride)"
    }

    if ($config.SystemLocale) {
        Set-WinSystemLocale -SystemLocale $config.SystemLocale
        Write-Log "SystemLocale applique : $($config.SystemLocale)"
    }

    if ($config.HomeLocationGeoId) {
        Set-WinHomeLocation -GeoId $config.HomeLocationGeoId
        Write-Log "HomeLocationGeoId applique : $($config.HomeLocationGeoId)"
    }

    if ($config.LanguageList) {
        $NouvelleListe = New-Object System.Collections.ObjectModel.Collection[Microsoft.InternationalSettings.Commands.WinUserLanguage]
        foreach ($Langue in @($config.LanguageList)) {
            $TagLangue = [string]$Langue.LanguageTag
            $ObjLangue = New-WinUserLanguageList -Language $TagLangue
            $ObjLangue[0].InputMethodTips.Clear()
            foreach ($Tip in @($Langue.InputMethodTips)) {
                $ObjLangue[0].InputMethodTips.Add([string]$Tip)
            }
            $NouvelleListe.Add($ObjLangue[0])
        }
        Set-WinUserLanguageList -LanguageList $NouvelleListe -Force
        Write-Log "LanguageList appliquee : $(($config.LanguageList | ForEach-Object { $_.LanguageTag }) -join ', ')"
    }

    # Fuseau horaire : utilise la valeur du fichier, ou Bruxelles/Belgique par defaut si absente
    $FuseauCible = if ($config.TimeZoneId) { $config.TimeZoneId } else { "Romance Standard Time" }
    Set-TimeZone -Id $FuseauCible
    Write-Log "Fuseau horaire applique : $FuseauCible"

    Write-Host "Configuration de langue d'affichage importee. Un redemarrage est recommande." -ForegroundColor Green
    Write-Log "=== Fin du script - configuration importee avec succes ==="
}