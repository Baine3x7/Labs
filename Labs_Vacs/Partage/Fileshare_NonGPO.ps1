<# Objectif :

Créer un dossier de partage de la vm qui est accessible sur tous les ordianteur de travail.
Mapper le lecteur sur tous les pcs 
Activer un partage accessible par tous 
Créer un user partage sur l'AD qui permet a tous le monde de se connecter

Difficulté : Travailler seulement sur le pc main (Machien de travail / Win11 Pro Baine)

#> 
ssh Administrator@home.lan

#1 Créer un dossier de partage 
New-Item -Directory -Path 'D:\Workgroup' -Force

#2 Mapper le lecteur sur tous les pcs (Win11 Pro Baine + Hote Win 11 Pro Baine_vm)
New-PSDrive -Name "W" -PSProvider FileSystem -Root "\\192.168.0.185"

#3 Créer un partage accessible par tous
New-SmbShare -Name "Workgroup" -Path "D:\Workgroup" -FullAccess "Everyone" -ChangeAccess "Everyone" -ReadAccess "Everyone"

#4 Un user partage sur l'AD qui permet a tous le monde de se connecter
New-ADuser -Name "BainePartage" -GivenName "Baine" -Surname "Partage" -SamAccountName "PBaine" -UserPrincipalName "pbaine@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)


New-Item -Directory -Path 'D:\Workgroup' -Force
New-PSDrive -Name "W" -PSProvider FileSystem -Root "\\192.168.0.185"
New-SmbShare -Name "Workgroup" -Path "D:\Workgroup" -FullAccess "Everyone" -ChangeAccess "Everyone" -ReadAccess "Everyone"
New-ADuser -Name "BainePartage" -GivenName "Baine" -Surname "Partage" -SamAccountName "PBaine" -UserPrincipalName "pbaine@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
