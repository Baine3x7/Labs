<#
    Cree un dossier par groupe de securite present dans OU_Groups,
    lui attribue le controle total (FullControl) au groupe correspondant,
    et coupe l'heritage des permissions parentes.
    A executer en tant qu'administrateur.

    Exemple :
      .\1.4_PermissionsDossiersGroupes.ps1
#>
param(
    [string]$CheminBase      = "D:\Partage",
    [string]$OU_GroupesCible = "OU=OU_Groups,DC=home,DC=lan"
)

Import-Module ActiveDirectory

# --- Rapport texte horodate ---
$Horodatage       = Get-Date -Format "yyyyMMdd_HHmmss"
$CheminRapportTxt = ".\1.3_rapport_permissions_groupes_$Horodatage.txt"

# Cree le dossier Rapports s'il n'existe pas encore (evite l'erreur au 1er lancement)
New-Item -Path ".\" -ItemType Directory -Force | Out-Null

function Write-Log {
    param([string]$Message)
    $Ligne = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $CheminRapportTxt -Value $Ligne -Encoding UTF8
}

Write-Log "=== Debut du script de creation des dossiers de groupes ==="

# Recupere tous les groupes de securite presents dans OU_Groups
$Groupes = Get-ADGroup -Filter * -SearchBase $OU_GroupesCible

if (-not $Groupes) {
    Write-Warning "Aucun groupe trouve dans '$OU_GroupesCible'."
    Write-Log "ATTENTION - Aucun groupe trouve dans '$OU_GroupesCible'. Arret du script."
    exit
}

foreach ($Groupe in $Groupes) {

    $NomGroupe    = $Groupe.Name
    $CheminDossier = Join-Path $CheminBase $NomGroupe

    try {
        # 1) Creation du dossier (le nom reprend celui du groupe)
        New-Item -Path $CheminDossier -ItemType Directory -Force | Out-Null
        Write-Host "Dossier cree : $CheminDossier" -ForegroundColor Green
        Write-Log "OK - Dossier cree : $CheminDossier"

        # 2) Attribution des permissions NTFS
        $Acl = Get-Acl $CheminDossier

        # Coupe l'heritage des permissions du dossier parent, sans conserver les regles heritees
        $Acl.SetAccessRuleProtection($true, $false)

        # Controle total pour le groupe, applique aux sous-dossiers et fichiers (presents et futurs)
        $Regle = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $NomGroupe, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $Acl.AddAccessRule($Regle)

        # Administrator et Domain Admins gardent toujours un controle total, meme apres
        # la coupure de l'heritage (sinon ils perdraient l'acces s'ils ne l'avaient que par heritage)
        foreach ($CompteAdmin in @("Administrator", "Domain Admins")) {
            $RegleAdmin = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $CompteAdmin, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            $Acl.AddAccessRule($RegleAdmin)
        }

        Set-Acl $CheminDossier $Acl

        Write-Host "  -> Permissions FullControl accordees a '$NomGroupe', 'Administrator' et 'Domain Admins'" -ForegroundColor Cyan
        Write-Log "  -> Permissions FullControl accordees a '$NomGroupe' sur '$CheminDossier'"
        Write-Log "  -> Permissions FullControl accordees a 'Administrator' et 'Domain Admins' sur '$CheminDossier'"
        Write-Log "  -> Heritage coupe (les droits du dossier parent ne s'appliquent plus)"
    }
    catch {
        Write-Warning "Erreur pour le groupe '$NomGroupe' : $_"
        Write-Log "ERREUR - Groupe '$NomGroupe' ($CheminDossier) : $_"
        continue
    }
}

Write-Host "`nTraitement termine." -ForegroundColor Yellow
Write-Log "=== Fin du script - $($Groupes.Count) groupe(s) traite(s) ==="
Write-Host "Rapport texte : $CheminRapportTxt" -ForegroundColor Yellow

# Verification :
# Get-Acl "D:\Partage\GS_Dir" | Format-List
# icacls "D:\Partage\GS_Dir"