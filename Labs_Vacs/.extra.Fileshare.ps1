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

#2 Créer un partage accessible par tous
New-SmbShare -Name "Workgroup" -Path "D:\Workgroup" -FullAccess "Everyone" -ChangeAccess "Everyone" -ReadAccess "Everyone"

#3 Donnez les permissions NTFS sur le dossier partagé pour que tout le monde puisse y accéder
icacls "D:\Workgroup" /grant "Everyone:(OI)(CI)F" /inheritance:r

#4 Mapper le lecteur sur tous les pcs (Win11 Pro Baine + Hote Win 11 Pro Baine_vm)
New-PSDrive -Name "W" -PSProvider FileSystem -Root "\\192.168.0.185\Workgroup" -Persist

#5 Un user partage sur l'AD qui permet a tous le monde de se connecter
New-ADuser -Name "BainePartage" -GivenName "Baine" -Surname "Partage" -SamAccountName "PBaine" -UserPrincipalName "pbaine@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)


New-Item -Path "D:\Workgroup" -ItemType Directory -Force
New-SmbShare -Name "Workgroup" -Path "D:\Workgroup" -FullAccess "Everyone" -ChangeAccess "Everyone" -ReadAccess "Everyone"
icacls "D:\Workgroup" /grant "Everyone:(OI)(CI)F" /inheritance:r
New-ADuser -Name "BainePartage" -GivenName "Baine" -Surname "Partage" -SamAccountName "PBaine" -UserPrincipalName "pbaine@home.lan" -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force)
New-PSDrive -Name "W" -PSProvider FileSystem -Root "\\192.168.0.185\Workgroup\" -Persist -Credential (Get-Credential)