<#
.SYNOPSIS
    Désactive les comptes AD inactifs depuis plus de X jours (LastLogonDate).

.DESCRIPTION
    Recherche les utilisateurs actifs dont LastLogonDate dépasse le seuil défini,
    les désactive, ajoute une description horodatée, et génère un rapport CSV + log.

.PARAMETER JoursInactivite
    Nombre de jours d'inactivité avant désactivation (défaut : 90).

.PARAMETER OUCible
    OU de recherche (par défaut : tout le domaine).

.PARAMETER CheminRapport
    Dossier où seront générés le rapport CSV et le fichier de log.

.PARAMETER Simulation
    Si activé, liste les comptes concernés sans les désactiver réellement.

.EXAMPLE
    .\Disable-InactiveUsers.ps1 -Simulation
    .\Disable-InactiveUsers.ps1 -JoursInactivite 90 -OUCible "OU=Utilisateurs,DC=corp,DC=local"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$JoursInactivite = 90,
    [string]$OUCible = (Get-ADDomain).DistinguishedName,
    [string]$CheminRapport = ".",
    [switch]$Simulation
)

Import-Module ActiveDirectory -ErrorAction Stop

# --- Préparation ---
$DateSeuil   = (Get-Date).AddDays(-$JoursInactivite)
$Horodatage  = Get-Date -Format "yyyyMMdd_HHmmss"

$FichierLog    = Join-Path $CheminRapport "1.4_rapport_desactivationLog_$Horodatage.log"
$FichierRapport = Join-Path $CheminRapport "1.4_comptes_desactives_$Horodatage.csv"

function Write-Log {
    param([string]$Message)
    $Ligne = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $FichierLog -Value $Ligne
    Write-Host $Ligne
}

Write-Log "=== Début du script — seuil : $JoursInactivite jours (avant le $($DateSeuil.ToString('yyyy-MM-dd'))) ==="

# --- Récupération des comptes concernés ---
# On exclut les comptes déjà désactivés et ceux sans LastLogonDate (jamais connectés = à traiter à part si besoin)
$UtilisateursInactifs = Get-ADUser -SearchBase $OUCible -Filter {
    (Enabled -eq $true) -and (LastLogonDate -lt $DateSeuil) -and (LastLogonDate -like "*")
} -Properties LastLogonDate, DistinguishedName, EmailAddress

Write-Log "Nombre de comptes inactifs détectés : $($UtilisateursInactifs.Count)"

$Resultats = foreach ($Utilisateur in $UtilisateursInactifs) {

    $Statut = "Non traité"

    if ($Simulation) {
        $Statut = "SIMULATION - serait désactivé"
        Write-Log "[SIMULATION] $($Utilisateur.SamAccountName) — dernière connexion : $($Utilisateur.LastLogonDate)"
    }
    else {
        if ($PSCmdlet.ShouldProcess($Utilisateur.SamAccountName, "Désactiver le compte")) {
            try {
                Disable-ADAccount -Identity $Utilisateur.DistinguishedName -ErrorAction Stop

                $DescriptionActuelle = (Get-ADUser $Utilisateur -Properties Description).Description
                $NouvelleDescription = "Désactivé auto le $(Get-Date -Format 'yyyy-MM-dd') — inactif depuis $JoursInactivite+ jours"
                Set-ADUser -Identity $Utilisateur.DistinguishedName -Description $NouvelleDescription

                $Statut = "Désactivé avec succès"
                Write-Log "OK - $($Utilisateur.SamAccountName) désactivé (dernière connexion : $($Utilisateur.LastLogonDate))"
            }
            catch {
                $Statut = "ERREUR : $($_.Exception.Message)"
                Write-Log "ERREUR - $($Utilisateur.SamAccountName) : $($_.Exception.Message)"
            }
        }
    }

    [PSCustomObject]@{
        SamAccountName    = $Utilisateur.SamAccountName
        Nom               = $Utilisateur.Name
        Email             = $Utilisateur.EmailAddress
        DerniereConnexion = $Utilisateur.LastLogonDate
        DistinguishedName = $Utilisateur.DistinguishedName
        Statut            = $Statut
    }
}

# --- Export du rapport ---
if ($Resultats) {
    $Resultats | Export-Csv -Path $FichierRapport -Delimiter ";" -Encoding UTF8 -NoTypeInformation
    Write-Log "Rapport exporté : $FichierRapport"
}
else {
    Write-Log "Aucun compte à traiter."
}

Write-Log "=== Fin du script ==="