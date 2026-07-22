<#
.SYNOPSIS
    Fusionne tous les rapports texte (.txt/.log) d'un dossier en un rapport global unique,
    trie chronologiquement par l'horodatage reel de chaque ligne (pas par ordre de fichier).

.DESCRIPTION
    Parcourt le dossier de rapports (par defaut .\Rapports, utilise par les scripts 1.4.1 et 1.8),
    lit chaque fichier .txt/.log ligne par ligne, extrait l'horodatage "yyyy-MM-dd HH:mm:ss"
    en debut de ligne (format produit par la fonction Write-Log des autres scripts), et produit
    un fichier unique ou chaque ligne est prefixee par le nom du script source, triee dans
    l'ordre chronologique reel des evenements.

.PARAMETER DossierRapports
    Dossier contenant les rapports individuels a fusionner (defaut : .\Rapports)

.PARAMETER CheminSortie
    Chemin du rapport global genere (defaut : .\Rapports\Rapport_Global_<horodatage>.txt)

.PARAMETER Nettoyer
    Si active, deplace les rapports individuels dans un sous-dossier ".oldrapport"
    une fois fusionnes avec succes, au lieu de les supprimer (une confirmation est
    demandee pour chaque fichier, sauf avec -Confirm:$false).

.EXAMPLE
    .\1.9_Merge_Rapports.ps1
    .\1.9_Merge_Rapports.ps1 -DossierRapports "C:\Temp\Rapports" -CheminSortie "C:\Temp\Global.txt"
    .\1.9_Merge_Rapports.ps1 -Nettoyer
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [string]$DossierRapports = "..",
    [string]$CheminSortie    = ".\Rapport_Global_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt",
    [switch]$Nettoyer
)

if (-not (Test-Path $DossierRapports)) {
    Write-Error "Dossier introuvable : $DossierRapports"
    exit 1
}

# Cree le dossier de sortie si besoin (au cas ou -CheminSortie pointe ailleurs)
$DossierSortie = Split-Path -Path $CheminSortie -Parent
if ($DossierSortie -and -not (Test-Path $DossierSortie)) {
    New-Item -Path $DossierSortie -ItemType Directory -Force | Out-Null
}

# On recupere tous les .txt/.log du dossier, en excluant un eventuel rapport global precedent
# et le sous-dossier .oldrapport (rapports deja archives lors d'une fusion precedente)
$Fichiers = Get-ChildItem -Path $DossierRapports -Include "*.txt", "*.log" -Recurse -File |
    Where-Object { $_.Name -notlike "Rapport_Global_*" -and $_.DirectoryName -notlike "*\.oldrapport*" }

if (-not $Fichiers) {
    Write-Warning "Aucun rapport .txt/.log trouve dans $DossierRapports"
    exit
}

Write-Host "Fichiers detectes : $($Fichiers.Count)" -ForegroundColor Yellow
$Fichiers | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Cyan }

$RegexDate = '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'

$ToutesLesLignes = foreach ($Fichier in $Fichiers) {
    Get-Content -Path $Fichier.FullName | ForEach-Object {
        if ($_.Trim() -ne "") {
            # Si la ligne commence par un horodatage reconnu, on l'utilise pour le tri.
            # Sinon (ligne orpheline, format different), on retombe sur la date de derniere
            # modification du fichier pour ne pas perdre l'information.
            $DateLigne = if ($_ -match $RegexDate) {
                [datetime]::ParseExact($Matches[0], "yyyy-MM-dd HH:mm:ss", $null)
            } else {
                $Fichier.LastWriteTime
            }

            [PSCustomObject]@{
                Source = $Fichier.Name
                Ligne  = $_
                Date   = $DateLigne
            }
        }
    }
}

$Trie = $ToutesLesLignes | Sort-Object Date

$Sortie = @("=== Rapport global genere le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===", "")
$Sortie += foreach ($Entree in $Trie) {
    "[$($Entree.Source)] $($Entree.Ligne)"
}

$Sortie | Out-File -FilePath $CheminSortie -Encoding UTF8

Write-Host "`nRapport global genere : $CheminSortie" -ForegroundColor Green
Write-Host "$($Fichiers.Count) fichier(s) fusionne(s), $($Trie.Count) ligne(s) au total" -ForegroundColor Green

# --- Archivage des rapports individuels (optionnel) ---
if ($Nettoyer) {
    # Sous-dossier d'archive, cree a cote des rapports d'origine
    $DossierArchive = Join-Path $DossierRapports ".oldrapport"
    if (-not (Test-Path $DossierArchive)) {
        New-Item -Path $DossierArchive -ItemType Directory -Force | Out-Null
    }

    foreach ($Fichier in $Fichiers) {
        if ($PSCmdlet.ShouldProcess($Fichier.FullName, "Deplacer vers $DossierArchive (deja fusionne dans le rapport global)")) {
            Move-Item -Path $Fichier.FullName -Destination $DossierArchive -Force
            Write-Host "Deplace vers .oldrapport : $($Fichier.Name)" -ForegroundColor DarkYellow
        }
    }
}