# ImportUtilisateurs.ps1
# Import CSV (format: Nom;Prenom;Service) et création des comptes AD + ajout à un ou plusieurs groupes selon le(s) service(s)
# ⚠️ Sécurité : ce fichier récap contient les mots de passe en clair. 
# En usage réel (hors labo), il faudrait soit générer un mot de passe aléatoire par utilisateur, soit chiffrer/supprimer ce fichier après distribution. Vu que tu es sur home.lan, c'est probablement un environnement de test — mais je peux ajouter la génération de mots de passe aléatoires si tu veux t'entraîner à cette pratique aussi.

Import-Module ActiveDirectory

# --- Paramètres à adapter ---

# Création des OU si elles n'existent pas déjà (évite l'erreur au 2e lancement)
# Noms alignés sur le script principal (1.1) : OU_Users et OU_Groups
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'OU_Users'" -SearchBase "DC=home,DC=lan" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "OU_Users" -Path "DC=home,DC=lan"
    Write-Host "OU 'OU_Users' créée." -ForegroundColor Yellow
}
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'OU_Groups'" -SearchBase "DC=home,DC=lan" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "OU_Groups" -Path "DC=home,DC=lan"
    Write-Host "OU 'OU_Groups' créée." -ForegroundColor Yellow
}

$OU_Cible         = "OU=OU_Users,DC=home,DC=lan"
$OU_GroupesCible  = "OU=OU_Groups,DC=home,DC=lan"
$Domaine          = "home.lan"
$MotDePasseDefaut = 'Pa$$w0rd'   # guillemets simples : le $ n'est pas interprété
$CheminRecap      = ".\recap_comptes_crees.csv"
$PrefixeGroupe    = "GS_"        # convention du script principal : GS_Dir, GS_Tech, GS_HR
$GroupesSansPrefixe = @("Domain Admins")  # groupes intégrés à ne pas préfixer

# Détection automatique du fichier CSV (peu importe son nom exact, tant qu'il contient "utilisateurs")
$FichierCSV = Get-ChildItem -Path "." -Filter "*utilisateurs*.csv" | Select-Object -First 1

if (-not $FichierCSV) {
    Write-Error "Aucun fichier CSV contenant 'utilisateurs' trouvé dans le dossier courant."
    exit
}

$CheminCSV = $FichierCSV.FullName
Write-Host "Fichier CSV détecté : $($FichierCSV.Name)" -ForegroundColor Yellow

$SeparateurGroupes = ";"

# --- Fonction de translittération des accents (é->e, à->a, ç->c, etc.) ---
function Remove-Diacritics {
    param([string]$Texte)
    $NormalizedString = $Texte.Normalize([Text.NormalizationForm]::FormD)
    $StringBuilder = New-Object System.Text.StringBuilder
    foreach ($c in $NormalizedString.ToCharArray()) {
        $UnicodeCategory = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
        if ($UnicodeCategory -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$StringBuilder.Append($c)
        }
    }
    return $StringBuilder.ToString().Normalize([Text.NormalizationForm]::FormC)
}

$Utilisateurs = Import-Csv -Path $CheminCSV -Delimiter ","
$LoginsUtilises = Get-ADUser -Filter * -SearchBase $OU_Cible | Select-Object -ExpandProperty SamAccountName
$Recapitulatif = @()

foreach ($u in $Utilisateurs) {

    $Nom     = $u.Nom.Trim()
    $Prenom  = $u.Prenom.Trim()

    if ([string]::IsNullOrWhiteSpace($Nom) -or [string]::IsNullOrWhiteSpace($Prenom)) {
        Write-Warning "Ligne ignorée : Nom ou Prenom manquant."
        continue
    }

    $Groupes = $u.Service.Split($SeparateurGroupes) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    if ($Groupes.Count -eq 0) {
        Write-Warning "Attention : '$Prenom $Nom' n'a aucun service/groupe renseigné. Le compte sera créé sans groupe."
    }

    # Construction du login : accents translittérés, caractères non alphanumériques retirés
    $NomPropre    = Remove-Diacritics $Nom
    $PrenomPropre = Remove-Diacritics $Prenom
    $LoginBase = ("{0}{1}" -f $PrenomPropre.Substring(0,1), $NomPropre).ToLower() -replace '[^a-z0-9]', ''
    $SamAccountName = $LoginBase
    $Suffixe = 1

    while ($LoginsUtilises -contains $SamAccountName) {
        $Suffixe++
        $SamAccountName = "$LoginBase$Suffixe"
    }

    $UPN = "$SamAccountName@$Domaine"
    $NomComplet = "$Prenom $Nom"

    try {
        New-ADUser `
            -Name $NomComplet `
            -GivenName $Prenom `
            -Surname $Nom `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UPN `
            -Path $OU_Cible `
            -AccountPassword (ConvertTo-SecureString $MotDePasseDefaut -AsPlainText -Force) `
            -ChangePasswordAtLogon $true `
            -Department ($Groupes -join ", ") `
            -Enabled $true

        # Le mot de passe temporaire doit être changé à la 1ère connexion (ChangePasswordAtLogon ci-dessus).
        # Une fois ce changement fait par l'utilisateur, son nouveau mot de passe n'expirera jamais.
        Set-ADUser -Identity $SamAccountName -PasswordNeverExpires $true

        $LoginsUtilises += $SamAccountName
        Write-Host "Compte créé : $SamAccountName" -ForegroundColor Green
    }
    catch {
        Write-Warning "Erreur lors de la création de $SamAccountName : $_"
        continue
    }

    $GroupesReussis = @()

    foreach ($NomGroupe in $Groupes) {

        # Détermine le nom réel du groupe à rechercher/créer :
        # - "Domain Admins" et autres groupes intégrés : utilisés tels quels
        # - Les autres ("Tech", "Dir", "HR"...) : préfixés en "GS_Tech", "GS_Dir", "GS_HR"
        #   pour rejoindre les groupes déjà créés par le script principal (1.3),
        #   plutôt que de créer des groupes en double sans préfixe.
        if ($GroupesSansPrefixe -contains $NomGroupe) {
            $NomGroupeReel = $NomGroupe
        }
        else {
            $NomGroupeReel = "$PrefixeGroupe$NomGroupe"
        }

        $Groupe = Get-ADGroup -Filter "Name -eq '$NomGroupeReel'" -ErrorAction SilentlyContinue

        if ($Groupe) {
            Add-ADGroupMember -Identity $Groupe -Members $SamAccountName
            Write-Host "  -> Ajouté au groupe '$NomGroupeReel'" -ForegroundColor Cyan
        }
        else {
            Write-Warning "  -> Groupe '$NomGroupeReel' introuvable, création automatique dans OU_Groups..."
            New-ADGroup -Name $NomGroupeReel -GroupScope Global -GroupCategory Security -Path $OU_GroupesCible
            Add-ADGroupMember -Identity $NomGroupeReel -Members $SamAccountName
            Write-Host "  -> Groupe créé et utilisateur ajouté" -ForegroundColor Cyan
        }
        $GroupesReussis += $NomGroupeReel
    }

    # Ajout au récapitulatif
    $Recapitulatif += [PSCustomObject]@{
        NomComplet      = $NomComplet
        SamAccountName  = $SamAccountName
        UPN             = $UPN
        MotDePasse      = $MotDePasseDefaut
        Groupes         = ($GroupesReussis -join ", ")
    }
}

# --- Export du récapitulatif ---
if ($Recapitulatif.Count -gt 0) {
    $Recapitulatif | Export-Csv -Path $CheminRecap -Delimiter ";" -NoTypeInformation -Encoding UTF8
    Write-Host "`nRécapitulatif exporté vers : $CheminRecap" -ForegroundColor Yellow
}

Write-Host "Import terminé." -ForegroundColor Yellow

# Vérification :
# Get-ADUser -Filter *
# Get-ADUser -Filter * -Properties Department | Out-GridView
# Get-ADGroupMember -Identity "GS_Dir"


