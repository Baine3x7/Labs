# Retirer la veille windows
# Sur batterie
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
# Sur secteur
powercfg /change standby-timeout-dc 0
powercfg /change hibernate-timeout-dc 0

DC = SRV-AD
# Installation de l'Active Directory Module for Windows PowerShell
Install-WindowsFeature RSAT-AD-PowerShell

## 1.1.Création d'une unité d'organisation (OU) pour les utilisateurs
New-ADOrganizationalUnit -Name "OU_Users" -Path "DC=home,DC=lan"
New-ADOrganizationalUnit -Name "OU_Groups" -Path "DC=home,DC=lan"

## 1.2.Créer les utilisateurs
New-ADUser -Name "Baine" -GivenName "Baine" -Surname "baine" -SamAccountName "baine" -UserPrincipalName "baine@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true
New-ADUser -Name "Alice" -GivenName "Alice" -Surname "Neyer" -SamAccountName "nalice" -UserPrincipalName "alicen@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true
New-ADUser -Name "Bob" -GivenName "Bob" -Surname "Lenormand" -SamAccountName "lbob" -UserPrincipalName "bob@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true
New-ADUser -Name "Charlie" -GivenName "Charlie" -Surname "Brown" -SamAccountName "bcharlie" -UserPrincipalName "bcharlie@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true
New-ADUser -Name "David" -GivenName "David" -Surname "Lafarge" -SamAccountName "ldavid" -UserPrincipalName "david@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true
New-ADUser -Name "Yann" -GivenName "Yann" -Surname "Vanhemelryck" -SamAccountName "vyann" -UserPrincipalName "vyann@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true
New-ADUser -Name "Sebastien" -GivenName "Sebastien" -Surname "Sotiaux" -SamAccountName "ssebastien" -UserPrincipalName "ssebastien@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true
New-ADuser -Name "Jonathan" -GivenName "Jonathan" -Surname "Rippers" -SamAccountName "rjonathan" -UserPrincipalName "rjonathan@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) -ChangePasswordAtLogon $true

## 1.3.Créer les groupes et Ajouter les utilisateurs aux groupes
New-ADGroup -Name "GS_Dir" -GroupScope Global -Path "OU=OU_Groups,DC=home,DC=lan"
New-ADGroup -Name "GS_Tech" -GroupScope Global -Path "OU=OU_Groups,DC=home,DC=lan"
New-ADGroup -Name "GS_HR" -GroupScope Global -Path "OU=OU_Groups,DC=home,DC=lan"
Add-ADGroupMember -Identity "GS_Dir" -Members "vyann", "nalice"
Add-ADGroupMember -Identity "GS_HR" -Members "ldavid"
Add-ADGroupMember -Identity "GS_Tech" -Members "lbob", "bcharlie", "vyann", "ssebastien", "rjonathan", "Baine"
Add-ADGroupMember -Identity "Domain Admins" -Members "Baine"

Enable-ADAccount -Identity "Administrator" # Pour réactiver le compte Administrateur
Disable-ADAccount -Identity "Administrator" # Pour Desactiver le compte Administrateur

# Supprimer des utilisateurs et groupes pour réinitialiser l'environnement de test
Remove-ADUser -Identity "nalice" -Confirm:$false
Remove-ADUser -Identity "lbob" -Confirm:$false
Remove-ADUser -Identity "bcharlie" -Confirm:$false
Remove-ADUser -Identity "ldavid" -Confirm:$false
Remove-ADUser -Identity "Baine" -Confirm:$false
Remove-ADUser -Identity "vyann" -Confirm:$false
Remove-ADUser -Identity "ssebastien" -Confirm:$false
Remove-ADUser -Identity "rjonathan" -Confirm:$false
Remove-ADGroup -Identity "GS_Dir" -Confirm:$false
Remove-ADGroup -Identity "GS_Tech" -Confirm:$false
Remove-ADGroup -Identity "GS_HR" -Confirm:$false
Remove-ADOrganizationalUnit -Identity "Groupes" -Confirm:$false
Remove-ADOrganizationalUnit -Identity "Utilisateurs" -Confirm:$false

# Deplacer un utilisateur dans une autre OU
# Move-ADObject -Identity "CN=Baine,CN=Users,DC=home,DC=lan" -TargetPath "OU=OU_Users,DC=home,DC=lan"
Get-ADUser -Identity "Baine" | Move-ADObject -TargetPath "OU=OU_Users,DC=home,DC=lan"

# Vérification
Get-ADUser -Identity "Baine" | Select-Object Name, DistinguishedName

# Name  DistinguishedName
# ----  -----------------
# Baine CN=Baine,OU=OU_Users,DC=home,DC=lan


## 1.4 Ecrire un script PowerShell pour créer les utilisateurs et les groupes à partir d'un fichier CSV
powershell.exe -ExecutionPolicy bypass 1.4.1_Create_Users.ps1
powershell.exe -ExecutionPolicy bypass 1.4.2_utilisateurs.csv

## 1.5 Créer un partage de fichiers et configurer les permissions pour les groupes
# Pour cet exercice, on va créer un disque dur de 10 GB pour pas mélanger l'os et les fichiers partagés. On va créer un disque dur virtuel (VHDX) de 10 GB, le formater en NTFS, le monter sur le serveur et le partager avec les groupes GS_Dir et GS_Tech.
# Ce disque sera le disque D:.
# Dans un premier temps, créer l'arborescence suivante sur le disque D:
mkdir D:\Partage\Dir
mkdir D:\Partage\Tech
mkdir D:\Partage\HR
mkdir D:\Partage\Public

# Les permissions seront les suivantes :
# GS_Tech aura accès sur tous les fichiers du dossier D:\Partage 
# GS_Dir : Full Control sur D:\Partage\Dir
# GS_HR : Full Control sur D:\Partage\HR
# Everyone : Read sur D:\Partage\Public

# Pour créer le partage, on va utiliser la commande New-SmbShare. On va créer un partage nommé "Partage" sur le dossier D:\Partage. On va configurer les permissions pour les groupes GS_Tech, GS_Dir et GS_HR.
# Un seul partage, ouvert à tous les groupes concernés au niveau SMB
New-SmbShare -Name "Partage" -Path "D:\Partage" -FullAccess "GS_Tech", "GS_Dir", "GS_HR" -ReadAccess "Everyone"

# La restriction réelle se fait ensuite via les ACL NTFS sur chaque sous-dossier
# 1. D'abord bloquer l'héritage sur les sous-dossiers sensibles ((/inheritance:r) pour ne pas hériter des droits du parent)
icacls "D:\Partage\Dir"    /inheritance:r
icacls "D:\Partage\HR"     /inheritance:r
icacls "D:\Partage\Public" /inheritance:r

# 2. Puis accorder les droits spécifiques à chacun ((/grant) sur les sous-dossiers sensibles)
icacls "D:\Partage\Dir"    /grant "GS_Dir:(OI)(CI)F"
icacls "D:\Partage\HR"     /grant "GS_HR:(OI)(CI)F"
icacls "D:\Partage\Public" /grant "Everyone:(OI)(CI)R"

# 3. Enfin, accorder GS_Tech sur le parent — ne touchera plus Dir/HR/Public
icacls "D:\Partage" /grant "GS_Tech:(OI)(CI)F" /inheritance:r

# 4. Vérifier les permissions sur les dossiers partagés
icacls "D:\Partage"

# 5. Vérifier les permissions sur les sous-dossiers sensibles par groupes
(Get-Acl "D:\Partage\Tech").Access | Where-Object { $_.IdentityReference -like "*GS_Tech*" }
(Get-Acl "D:\Partage\Dir").Access | Where-Object { $_.IdentityReference -like "*GS_Dir*" }
(Get-Acl "D:\Partage\HR").Access | Where-Object { $_.IdentityReference -like "*GS_HR*" }

#Les commandes ne doivent rien retourner pour les groupes qui n'ont pas accès.

## 1.6 Mettre en place un dossier par service avec des permissions NTFS héritées différentes. Les techniciens n'ont pas accès aux dossiers de Direction.
icacls "D:\Partage\Dir" | Select-String "Inherited"
# Cette commande ne doit rien retourner







