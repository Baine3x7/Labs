# Import utilisateurs.ps1
# Import CSV (format: Nom,Prenom,Service — le champ Service est entre guillemets s'il contient
# plusieurs valeurs séparées par ";", ex: "Domain Admins; Tech; Dir") et création des comptes AD
# + ajout à un ou plusieurs groupes selon le(s) service(s)
# ⚠️ Sécurité : ce fichier récap contient les mots de passe en clair. 
# En usage réel (hors labo), il faudrait soit générer un mot de passe aléatoire par utilisateur, soit chiffrer/supprimer ce fichier après distribution. Vu que tu es sur home.lan, c'est probablement un environnement de test — mais je peux ajouter la génération de mots de passe aléatoires si tu veux t'entraîner à cette pratique aussi.

Import-Module ActiveDirectory

# --- Rapport texte horodaté ---
$Horodatage       = Get-Date -Format "yyyyMMdd_HHmmss"
$CheminRapportTxt = ".\1.2_rapport_creation_utilisateurs_$Horodatage.txt"

function Write-Log {
    param([string]$Message)
    $Ligne = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $CheminRapportTxt -Value $Ligne -Encoding UTF8
}

Write-Log "=== Debut du script de creation d'utilisateurs ==="

# --- Paramètres à adapter ---

# Création des OU si elles n'existent pas déjà (évite l'erreur au 2e lancement)
# Noms alignés sur le script principal (1.1) : OU_Users et OU_Groups
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'OU_Users'" -SearchBase "DC=home,DC=lan" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "OU_Users" -Path "DC=home,DC=lan"
    Write-Host "OU 'OU_Users' créée." -ForegroundColor Yellow
    Write-Log "OU 'OU_Users' creee."
}
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'OU_Groups'" -SearchBase "DC=home,DC=lan" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "OU_Groups" -Path "DC=home,DC=lan"
    Write-Host "OU 'OU_Groups' créée." -ForegroundColor Yellow
    Write-Log "OU 'OU_Groups' creee."
}

$OU_Cible         = "OU=OU_Users,DC=home,DC=lan"
$OU_GroupesCible  = "OU=OU_Groups,DC=home,DC=lan"
$Domaine          = "home.lan"
$MotDePasseDefaut = 'Pa$$w0rd'   # guillemets simples : le $ n'est pas interprété
$CheminRecap      = ".\1.2_recap_comptes_crees.txt"
$PrefixeGroupe    = "GS_"        # convention du script principal : GS_Dir, GS_Tech, GS_HR
$GroupesSansPrefixe = @("Domain Admins")  # groupes intégrés à ne pas préfixer

# Détection automatique du fichier CSV (peu importe son nom exact, tant qu'il contient "utilisateurs")
# CORRECTIF : Get-ChildItem retourne un vrai objet fichier (avec .FullName / .Name),
# contrairement à l'ancienne version qui forçait un [string] puis appelait .FullName dessus
# (ce qui renvoie silencieusement $null et casse l'import plus loin).
$FichierCSV = Get-ChildItem -Path $PSScriptRoot -Filter "*utilisateurs*.csv" | Select-Object -First 1

if (-not $FichierCSV) {
    Write-Error "Aucun fichier CSV contenant 'utilisateurs' introuvable dans le dossier courant."
    Write-Log "ERREUR - Aucun fichier CSV 'utilisateurs' trouve. Arret du script."
    exit
}

$CheminCSV = $FichierCSV.FullName
Write-Host "Fichier CSV détecté : $($FichierCSV.Name)" -ForegroundColor Yellow
Write-Log "Fichier CSV detecte : $($FichierCSV.Name)"

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

# Le CSV réel est délimité par des virgules (Nom,Prenom,Service), avec le champ Service
# entre guillemets et ses valeurs multiples séparées par ";" (ex: "Domain Admins; Tech; Dir").
# C'est bien -Delimiter "," qu'il faut utiliser ici -> ne pas confondre avec le séparateur
# interne des groupes ($SeparateurGroupes) qui, lui, est bien ";".
$Utilisateurs = Import-Csv -Path $CheminCSV -Delimiter ","
$LoginsUtilises = Get-ADUser -Filter * -SearchBase $OU_Cible | Select-Object -ExpandProperty SamAccountName
$Recapitulatif = @()

foreach ($u in $Utilisateurs) {

    $Nom     = $u.Nom.Trim()
    $Prenom  = $u.Prenom.Trim()

    if ([string]::IsNullOrWhiteSpace($Nom) -or [string]::IsNullOrWhiteSpace($Prenom)) {
        Write-Warning "Ligne ignorée : Nom ou Prenom manquant."
        Write-Log "IGNORE - Ligne avec Nom ou Prenom manquant."
        continue
    }

    $Groupes = $u.Service.Split($SeparateurGroupes) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    if ($Groupes.Count -eq 0) {
        Write-Warning "Attention : '$Prenom $Nom' n'a aucun service/groupe renseigné. Le compte sera créé sans groupe."
        Write-Log "ATTENTION - '$Prenom $Nom' sans service/groupe renseigne. Compte cree sans groupe."
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
        Write-Log "OK - Compte cree : $SamAccountName ($NomComplet)"
    }
    catch {
        Write-Warning "Erreur lors de la création de $SamAccountName : $_"
        Write-Log "ERREUR - Creation de $SamAccountName ($NomComplet) : $_"
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
            Write-Log "  -> $SamAccountName ajoute au groupe '$NomGroupeReel'"
        }
        else {
            Write-Warning "  -> Groupe '$NomGroupeReel' introuvable, création automatique dans OU_Groups..."
            New-ADGroup -Name $NomGroupeReel -GroupScope Global -GroupCategory Security -Path $OU_GroupesCible
            Add-ADGroupMember -Identity $NomGroupeReel -Members $SamAccountName
            Write-Host "  -> Groupe créé et utilisateur ajouté" -ForegroundColor Cyan
            Write-Log "  -> Groupe '$NomGroupeReel' cree, $SamAccountName ajoute"
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
    Write-Log "Recapitulatif CSV exporte vers : $CheminRecap"
}

Write-Host "Import terminé." -ForegroundColor Yellow
Write-Log "=== Fin du script - $($Recapitulatif.Count) compte(s) cree(s) sur $($Utilisateurs.Count) ligne(s) du CSV ==="
Write-Host "Rapport texte : $CheminRapportTxt" -ForegroundColor Yellow

# Vérification :
# Get-ADUser -Filter *
# Get-ADUser -Filter * -Properties Department | Out-GridView
# Get-ADGroupMember -Identity "GS_Dir"