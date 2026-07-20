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

# 1.Création d'une unité d'organisation (OU) pour les utilisateurs
New-ADOrganizationalUnit -Name "Utilisateurs" -Path "DC=home,DC=lan"

# 2.Créer les utilisateurs
New-ADUser -Name "Baine" -GivenName "Baine" -Surname "baine" -SamAccountName "baine" -UserPrincipalName "baine"
New-ADUser -Name "Alice" -GivenName "Alice" -Surname "Neyer" -SamAccountName "alicen" -UserPrincipalName "alicen"
New-ADUser -Name "Bob" -GivenName "Bob" -Surname "Lenormand" -SamAccountName "bob" -UserPrincipalName "bob"
New-ADUser -Name "Charlie" -GivenName "Charlie" -Surname "Brown" -SamAccountName "charlie" -UserPrincipalName "charlie"
New-ADUser -Name "David" -GivenName "David" -Surname "Lafarge" -SamAccountName "david" -UserPrincipalName "david"

# 3.1.Créer les groupes et Ajouter les utilisateurs aux groupes
New-ADGroup -Name "GS_Dir" -GroupScope Global -Path "OU=Utilisateurs,DC=home,DC=lan"
New-ADGroup -Name "GS_Tech" -GroupScope Global -Path "OU=Utilisateurs,DC=home,DC=lan"
Add-ADGroupMember -Identity "GS_Dir" -Members "Baine", "Alice"
Add-ADGroupMember -Identity "GS_Tech" -Members "Bob", "Charlie"
Add-ADGroupMember -Identity "Domain Admins" -Members "Baine"

# 4.1 

