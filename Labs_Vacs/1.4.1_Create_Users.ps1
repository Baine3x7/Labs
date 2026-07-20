# ImportUtilisateurs.ps1
# Import CSV (format: Nom;Prenom;Service) et création des comptes AD + ajout à un ou plusieurs groupes selon le(s) service(s)
# ⚠️ Sécurité : ce fichier récap contient les mots de passe en clair. 
# En usage réel (hors labo), il faudrait soit générer un mot de passe aléatoire par utilisateur, soit chiffrer/supprimer ce fichier après distribution. Vu que tu es sur home.lan, c'est probablement un environnement de test — mais je peux ajouter la génération de mots de passe aléatoires si tu veux t'entraîner à cette pratique aussi.

Import-Module ActiveDirectory

# --- Paramètres à adapter ---
New-ADOrganizationalUnit -Name "Utilisateurs" -Path "DC=home,DC=lan"
$CheminCSV        = ".\1.4.2_utilisateurs.csv"
$OU_Cible         = "OU=Utilisateurs,DC=home,DC=lan"
$Domaine          = "home.lan"
$MotDePasseDefaut = 'Pa$$w0rd'   # guillemets simples : le $ n'est pas interprété
$CheminRecap      = "C:\Import\recap_comptes_crees.csv"

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

        $LoginsUtilises += $SamAccountName
        Write-Host "Compte créé : $SamAccountName" -ForegroundColor Green
    }
    catch {
        Write-Warning "Erreur lors de la création de $SamAccountName : $_"
        continue
    }

    $GroupesReussis = @()

    foreach ($NomGroupe in $Groupes) {

        $Groupe = Get-ADGroup -Filter "Name -eq '$NomGroupe'" -ErrorAction SilentlyContinue

        if ($Groupe) {
            Add-ADGroupMember -Identity $Groupe -Members $SamAccountName
            Write-Host "  -> Ajouté au groupe '$NomGroupe'" -ForegroundColor Cyan
        }
        else {
            Write-Warning "  -> Groupe '$NomGroupe' introuvable, création automatique..."
            New-ADGroup -Name $NomGroupe -GroupScope Global -GroupCategory Security -Path $OU_Cible
            Add-ADGroupMember -Identity $NomGroupe -Members $SamAccountName
            Write-Host "  -> Groupe créé et utilisateur ajouté" -ForegroundColor Cyan
        }
        $GroupesReussis += $NomGroupe
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

# Vérfication :
# Get-ADUser -Filter *
# Get-ADUser -Filter * -Properties Department | Out-GridView

# Ligne 16 — $SeparateurGroupes = ";"
# C'est le séparateur utilisé à l'intérieur d'une seule cellule, dans la colonne Service, pour distinguer plusieurs groupes entre eux.
# Exemple : dans "Domain Admins; Tech; Dir", ce séparateur découpe cette chaîne en trois groupes : Domain Admins, Tech, Dir.
# → À changer en ";" puisque c'est ce caractère qui sépare tes groupes dans le fichier.
# Ligne 32 — Import-Csv -Path $CheminCSV -Delimiter ","
# C'est le séparateur utilisé entre les colonnes du fichier CSV entier, pour distinguer Nom, Prenom et Service les uns des autres.
# Exemple : dans Baine,Tech,"Domain Admins; Tech; Dir", ce délimiteur découpe la ligne en trois colonnes.
# → À changer en "," puisque ton fichier sépare ses colonnes avec des virgules.
# En résumé
# Ligne	Rôle	Valeur actuelle	Valeur correcte
# 16	Sépare les groupes dans la colonne Service	,	;
# 32	Sépare les colonnes entre elles	;	,
# Les deux valeurs sont simplement inversées par rapport à ce qu'il faut. Une fois corrigées, le script lira correctement Nom, Prenom, Service, puis découpera "Domain Admins; Tech; Dir" en trois groupes distincts.


