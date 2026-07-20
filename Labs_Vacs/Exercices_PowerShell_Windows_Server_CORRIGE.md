# Exercices PowerShell — Administration Windows Server (CORRIGÉ)

⚠️ Ce fichier contient les réponses. Adapte les noms (domaine, serveurs, chemins) à ton environnement de labo avant d'exécuter.

---

## 1. Utilisateurs, Groupes, Partage de fichiers (Active Directory)

**1. Créer l'OU `Personnel` avec sous-OU `Direction` et `Techniciens`**
```powershell
New-ADOrganizationalUnit -Name "Personnel" -Path "DC=entreprise,DC=local"
New-ADOrganizationalUnit -Name "Direction" -Path "OU=Personnel,DC=entreprise,DC=local"
New-ADOrganizationalUnit -Name "Techniciens" -Path "OU=Personnel,DC=entreprise,DC=local"
```

**2. Créer 5 utilisateurs avec changement de mot de passe obligatoire**
```powershell
$utilisateurs = @(
    @{Prenom="Alice"; Nom="Martin"},
    @{Prenom="Bob";   Nom="Durand"},
    @{Prenom="Chloe"; Nom="Petit"},
    @{Prenom="David"; Nom="Bernard"},
    @{Prenom="Eva";   Nom="Robert"}
)

foreach ($u in $utilisateurs) {
    $sam = ($u.Prenom.Substring(0,1) + $u.Nom).ToLower()
    New-ADUser -Name "$($u.Prenom) $($u.Nom)" `
        -GivenName $u.Prenom -Surname $u.Nom `
        -SamAccountName $sam -UserPrincipalName "$sam@entreprise.local" `
        -Path "OU=Techniciens,OU=Personnel,DC=entreprise,DC=local" `
        -AccountPassword (ConvertTo-SecureString "P@ssw0rd!2024" -AsPlainText -Force) `
        -ChangePasswordAtLogon $true -Enabled $true
}
```

**3. Créer les groupes et ajouter les membres**
```powershell
New-ADGroup -Name "GG_Direction" -GroupScope Global -GroupCategory Security -Path "OU=Direction,OU=Personnel,DC=entreprise,DC=local"
New-ADGroup -Name "GG_Techniciens" -GroupScope Global -GroupCategory Security -Path "OU=Techniciens,OU=Personnel,DC=entreprise,DC=local"

Add-ADGroupMember -Identity "GG_Techniciens" -Members "amartin","bdurand","cpetit"
Add-ADGroupMember -Identity "GG_Direction" -Members "dbernard","erobert"
```

**4. Import CSV + création automatique + affectation au bon groupe**
```powershell
# fichier employes.csv : Nom;Prenom;Service
Import-Csv -Path "C:\Scripts\employes.csv" -Delimiter ";" | ForEach-Object {
    $sam = ($_.Prenom.Substring(0,1) + $_.Nom).ToLower()
    $ouPath = if ($_.Service -eq "Direction") {
        "OU=Direction,OU=Personnel,DC=entreprise,DC=local"
    } else {
        "OU=Techniciens,OU=Personnel,DC=entreprise,DC=local"
    }

    New-ADUser -Name "$($_.Prenom) $($_.Nom)" -GivenName $_.Prenom -Surname $_.Nom `
        -SamAccountName $sam -UserPrincipalName "$sam@entreprise.local" `
        -Path $ouPath -AccountPassword (ConvertTo-SecureString "P@ssw0rd!2024" -AsPlainText -Force) `
        -ChangePasswordAtLogon $true -Enabled $true

    $groupe = if ($_.Service -eq "Direction") { "GG_Direction" } else { "GG_Techniciens" }
    Add-ADGroupMember -Identity $groupe -Members $sam
}
```

**5. Créer le partage `Commun` restreint à `GG_Direction`**
```powershell
New-Item -Path "D:\Partages\Commun" -ItemType Directory
New-SmbShare -Name "Commun" -Path "D:\Partages\Commun" -FullAccess "Tout le monde"
Revoke-SmbShareAccess -Name "Commun" -AccountName "Tout le monde" -Force
Grant-SmbShareAccess -Name "Commun" -AccountName "ENTREPRISE\GG_Direction" -AccessRight Full -Force
```

**6. Permissions NTFS différenciées par dossier de service**
```powershell
New-Item -Path "D:\Partages\Direction" -ItemType Directory
New-Item -Path "D:\Partages\Techniciens" -ItemType Directory

$acl = Get-Acl "D:\Partages\Direction"
$acl.SetAccessRuleProtection($true, $false)  # coupe l'héritage
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("ENTREPRISE\GG_Direction","FullControl","ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl -Path "D:\Partages\Direction" -AclObject $acl

$acl2 = Get-Acl "D:\Partages\Techniciens"
$acl2.SetAccessRuleProtection($true, $false)
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("ENTREPRISE\GG_Techniciens","Modify","ContainerInherit,ObjectInherit","None","Allow")
$acl2.AddAccessRule($rule2)
Set-Acl -Path "D:\Partages\Techniciens" -AclObject $acl2
```

**7. Audit des comptes désactivés et membres des groupes**
```powershell
Write-Host "=== Comptes désactivés ==="
Get-ADUser -Filter {Enabled -eq $false} -Properties Enabled | Select-Object Name, SamAccountName

Write-Host "=== Membres des groupes ==="
foreach ($g in "GG_Direction","GG_Techniciens") {
    Write-Host "--- $g ---"
    Get-ADGroupMember -Identity $g | Select-Object Name, SamAccountName
}
```

**8. Désactivation automatique des comptes inactifs depuis 90 jours**
```powershell
$seuil = (Get-Date).AddDays(-90)
Get-ADUser -Filter {LastLogonDate -lt $seuil -and Enabled -eq $true} -Properties LastLogonDate |
    ForEach-Object {
        Disable-ADAccount -Identity $_.SamAccountName
        Write-Host "Compte désactivé : $($_.SamAccountName) (dernière connexion : $($_.LastLogonDate))"
    }
```

---

## 2. DNS

**1. Créer la zone principale intégrée à AD**
```powershell
Add-DnsServerPrimaryZone -Name "entreprise.local" -ReplicationScope "Domain"
```

**2. Ajouter 3 enregistrements A**
```powershell
Add-DnsServerResourceRecordA -ZoneName "entreprise.local" -Name "srv-fichiers" -IPv4Address "192.168.1.10"
Add-DnsServerResourceRecordA -ZoneName "entreprise.local" -Name "srv-web" -IPv4Address "192.168.1.11"
Add-DnsServerResourceRecordA -ZoneName "entreprise.local" -Name "srv-appli" -IPv4Address "192.168.1.12"
```

**3. Ajouter un CNAME**
```powershell
Add-DnsServerResourceRecordCName -ZoneName "entreprise.local" -Name "intranet" -HostNameAlias "srv-web.entreprise.local"
```

**4. Zone inversée + test de résolution**
```powershell
Add-DnsServerPrimaryZone -NetworkID "192.168.1.0/24" -ReplicationScope "Domain"
Add-DnsServerResourceRecordPtr -ZoneName "1.168.192.in-addr.arpa" -Name "10" -PtrDomainName "srv-fichiers.entreprise.local"

Resolve-DnsName -Name "srv-fichiers.entreprise.local"
Resolve-DnsName -Name "10.1.168.192.in-addr.arpa" -Type PTR
```

**5. Enregistrement MX pour Exchange**
```powershell
Add-DnsServerResourceRecordMX -ZoneName "entreprise.local" -Name "@" -MailExchange "srv-exchange.entreprise.local" -Preference 10
```

**6. Script anti-doublon**
```powershell
$machines = @(
    @{Nom="srv-fichiers"; IP="192.168.1.10"},
    @{Nom="srv-backup";   IP="192.168.1.13"}
)

foreach ($m in $machines) {
    $existe = Get-DnsServerResourceRecord -ZoneName "entreprise.local" -Name $m.Nom -RRType A -ErrorAction SilentlyContinue
    if (-not $existe) {
        Add-DnsServerResourceRecordA -ZoneName "entreprise.local" -Name $m.Nom -IPv4Address $m.IP
        Write-Host "Ajouté : $($m.Nom)"
    } else {
        Write-Host "Déjà existant : $($m.Nom)"
    }
}
```

**7. Scavenging (nettoyage des enregistrements obsolètes)**
```powershell
Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00 -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00
Set-DnsServerZoneAging -Name "entreprise.local" -Aging $true
```

**8. Export des enregistrements d'une zone en CSV**
```powershell
Get-DnsServerResourceRecord -ZoneName "entreprise.local" |
    Select-Object HostName, RecordType, Timestamp, @{N="Data";E={$_.RecordData.IPv4Address}} |
    Export-Csv -Path "C:\Scripts\export_dns.csv" -NoTypeInformation -Delimiter ";"
```

---

## 3. WDS (Windows Deployment Services)

**1. Installation du rôle et initialisation**
```powershell
Install-WindowsFeature -Name WDS -IncludeManagementTools
wdsutil /Initialize-Server /RemInst:"D:\RemoteInstall"
```

**2 et 3. Montage de l'ISO + import des images (script automatisé)**
```powershell
$iso = Mount-DiskImage -ImagePath "D:\ISO\Win11_23H2.iso" -PassThru
$lettre = ($iso | Get-Volume).DriveLetter

wdsutil /Add-Image /ImageFile:"$($lettre):\sources\boot.wim" /ImageType:Boot
wdsutil /Add-Image /ImageFile:"$($lettre):\sources\install.wim" /ImageType:Install /ImageGroup:"ImageGroup1"

Dismount-DiskImage -ImagePath "D:\ISO\Win11_23H2.iso"
```

**4. Lister les images disponibles**
```powershell
wdsutil /Get-AllImages
# ou, plus lisible pour les images d'installation :
Get-WdsInstallImage | Select-Object ImageName, Architecture, FileSize
Get-WdsBootImage | Select-Object ImageName, Architecture, FileSize
```

**5. Préapprobation par adresse MAC**
```powershell
wdsutil /Set-Server /AutoAddPolicy /Policy:RequirePending
Set-WdsClient -DeviceID "00:15:5D:01:02:03" -DeviceName "PC-TEST01" -JoinDomain $true -JoinRights AllowIfAny
```

**6. Réponse PXE (tous vs connus)**
```powershell
# Répondre à tous les clients
wdsutil /Set-Server /AnswerClients:All

# Répondre uniquement aux clients connus (préapprouvés)
wdsutil /Set-Server /AnswerClients:Known
```

**7. Documentation du déploiement**
Étapes à consigner (pas de code unique, c'est un compte-rendu) :
1. Démarrage PXE du client (F12 / boot réseau).
2. Le client contacte le service DHCP puis le serveur WDS.
3. Téléchargement du `boot.wim`.
4. Sélection de l'image d'installation dans l'écran WDS.
5. Capture d'écran de chaque étape à inclure dans le rendu.

---

## 4. MDT (Microsoft Deployment Toolkit)

**1. Créer le partage de déploiement et le lecteur PSDrive**
```powershell
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

New-Item -Path "D:\DeploymentShare" -ItemType Directory
New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root "D:\DeploymentShare" -Description "Partage de déploiement" |
    Add-MDTPersistentDrive
```

**2. Importer un OS**
```powershell
Import-MDTOperatingSystem -Path "DS001:\Operating Systems" `
    -SourcePath "D:\ISO\Win11_23H2" -DestinationFolder "Windows 11 23H2"
```

**3. Créer une séquence de tâches standard**
```powershell
Import-MDTTaskSequence -Path "DS001:\Task Sequences" `
    -Name "Deploiement Win11 Standard" -Template "Client.xml" `
    -Comments "Séquence standard" -ID "W11-STD" `
    -Version "1.0" -OperatingSystemPath "DS001:\Operating Systems\Windows 11 23H2" `
    -FullName "Entreprise" -OrgName "Entreprise" -HomePage "about:blank"
```

**4. Importer une application et l'ajouter à la séquence**
```powershell
Import-MDTApplication -Path "DS001:\Applications" `
    -Name "7-Zip 23.01" -ShortName "7-Zip" -Version "23.01" -Publisher "Igor Pavlov" `
    -Language "FR" -CommandLine "7z2301-x64.msi /qn" `
    -WorkingDirectory ".\Applications\7-Zip" `
    -ApplicationSourcePath "D:\Sources\7zip" -DestinationFolder "7-Zip"

# Ajout à la séquence de tâches : se fait généralement via l'édition XML de la Task Sequence
# ou via la console MDT (pas de cmdlet dédiée simple pour insérer une étape).
```

**5. Modifier CustomSettings.ini**
```powershell
$content = @"
[Settings]
Priority=Default

[Default]
_SMSTSOrgName=Entreprise
OSInstall=Y
SkipComputerName=YES
SkipDomainMembership=YES
JoinDomain=entreprise.local
DomainAdmin=administrateur
DomainAdminDomain=entreprise.local
DomainAdminPassword=P@ssw0rd!
TimeZoneName=Romance Standard Time
SkipTimeZone=YES
SkipUserData=YES
SkipApplications=NO
SkipSummary=YES
SkipFinalSummary=YES
"@
Set-Content -Path "D:\DeploymentShare\Control\CustomSettings.ini" -Value $content -Encoding ASCII
```

**6. Régénérer les images et republier vers WDS**
```powershell
Update-MDTDeploymentShare -Path "DS001:" -Force

wdsutil /Add-Image /ImageFile:"D:\DeploymentShare\Boot\LiteTouchPE_x64.wim" /ImageType:Boot /ReplaceImage
```

**7. Injection de pilotes**
```powershell
Import-MDTDriver -Path "DS001:\Out-of-Box Drivers" -SourcePath "D:\Drivers\ReseauDellX" -ImportDuplicates
# Puis dans CustomSettings.ini, activer la sélection automatique des pilotes selon le modèle :
# DriverSelectionProfile=Nothing
# DriverGroup001=%Make%\%Model%
```

---

## 5. RDS (Remote Desktop Services)

**1. Installation d'un déploiement RDS basique**
```powershell
Import-Module RemoteDesktop

New-RDSessionDeployment -ConnectionBroker "srv-broker.entreprise.local" `
    -WebAccessServer "srv-broker.entreprise.local" `
    -SessionHost "srv-rds01.entreprise.local"
```

**2. Créer une collection de sessions**
```powershell
New-RDSessionCollection -CollectionName "Collection-Bureau" `
    -SessionHost "srv-rds01.entreprise.local" `
    -ConnectionBroker "srv-broker.entreprise.local"
```

**3. Publier une RemoteApp**
```powershell
New-RDRemoteApp -CollectionName "Collection-Bureau" `
    -DisplayName "Bloc-notes" -FilePath "C:\Windows\System32\notepad.exe" `
    -Alias "notepad" -ConnectionBroker "srv-broker.entreprise.local"
```

**4. Gérer les utilisateurs autorisés sur une collection**
```powershell
Set-RDSessionCollectionConfiguration -CollectionName "Collection-Bureau" `
    -UserGroup "ENTREPRISE\GG_Techniciens" `
    -ConnectionBroker "srv-broker.entreprise.local"
```

**5. Déconnexion automatique des sessions inactives**
```powershell
$seuilMinutes = 30
Get-RDUserSession -ConnectionBroker "srv-broker.entreprise.local" | ForEach-Object {
    if ($_.IdleTime -ge $seuilMinutes) {
        Disconnect-RDUser -HostServer $_.HostServer -UnifiedSessionID $_.UnifiedSessionId -Force
        Write-Host "Session déconnectée : $($_.UserName)"
    }
}
```

**6. Limites de session**
```powershell
Set-RDSessionCollectionConfiguration -CollectionName "Collection-Bureau" `
    -ConnectionBroker "srv-broker.entreprise.local" `
    -MaxIdleTime 1800000 `        # 30 minutes en millisecondes
    -MaxDisconnectionTime 3600000 # 60 minutes en millisecondes
```

**7. Rapport des sessions actives**
```powershell
Get-RDUserSession -ConnectionBroker "srv-broker.entreprise.local" |
    Select-Object UserName, CollectionName, CreateTime, SessionState |
    Export-Csv -Path "C:\Scripts\rapport_sessions_rds.csv" -NoTypeInformation -Delimiter ";"
```

**8. Configuration des licences RDS**
```powershell
Set-RDLicenseConfiguration -LicenseServer "srv-broker.entreprise.local" `
    -Mode PerUser -ConnectionBroker "srv-broker.entreprise.local" -Force
```

---

## 6. Exchange Server

**1. Activer une boîte aux lettres pour un utilisateur existant**
```powershell
Enable-Mailbox -Identity "amartin" -Database "Mailbox Database 0123456789"
```

**2. Groupe de distribution**
```powershell
New-DistributionGroup -Name "DG-Techniciens" -OrganizationalUnit "OU=Techniciens,OU=Personnel,DC=entreprise,DC=local"
Add-DistributionGroupMember -Identity "DG-Techniciens" -Member "bdurand"
Add-DistributionGroupMember -Identity "DG-Techniciens" -Member "cpetit"
```

**3. Quotas de boîte aux lettres**
```powershell
Set-Mailbox -Identity "amartin" `
    -IssueWarningQuota 1.8GB -ProhibitSendQuota 2GB -ProhibitSendReceiveQuota 2.3GB `
    -UseDatabaseQuotaDefaults $false
```

**4. Règle de transport : bloquer les pièces jointes > 10 Mo vers l'extérieur**
```powershell
New-TransportRule -Name "Bloquer PJ volumineuses externes" `
    -AttachmentSizeOver 10MB `
    -SentToScope NotInOrganization `
    -RejectMessageReasonText "Pièce jointe trop volumineuse pour un envoi externe (max 10 Mo)."
```

**5. Redirection automatique**
```powershell
Set-Mailbox -Identity "amartin" -ForwardingAddress "bdurand" -DeliverToMailboxAndForward $true
```

**6. Boîtes dépassant 80% du quota**
```powershell
Get-Mailbox -ResultSize Unlimited | ForEach-Object {
    $stats = Get-MailboxStatistics -Identity $_.Identity
    $tailleGo = [math]::Round(($stats.TotalItemSize.Value.ToBytes() / 1GB), 2)
    $quotaGo = [math]::Round(($_.ProhibitSendReceiveQuota.Value.ToBytes() / 1GB), 2)
    if ($quotaGo -gt 0 -and ($tailleGo / $quotaGo) -ge 0.8) {
        [PSCustomObject]@{Utilisateur=$_.DisplayName; TailleGo=$tailleGo; QuotaGo=$quotaGo}
    }
} | Format-Table -AutoSize
```

**7. Boîte partagée avec permissions**
```powershell
New-Mailbox -Shared -Name "Support" -DisplayName "Support Technique" -Alias "support"

Add-MailboxPermission -Identity "support" -User "bdurand" -AccessRights FullAccess -AutoMapping $true
Add-MailboxPermission -Identity "support" -User "cpetit" -AccessRights FullAccess -AutoMapping $true
Add-RecipientPermission -Identity "support" -Trustee "bdurand" -AccessRights SendAs -Confirm:$false
Add-RecipientPermission -Identity "support" -Trustee "cpetit" -AccessRights SendAs -Confirm:$false
```

**8. Réponse d'absence automatique**
```powershell
Set-MailboxAutoReplyConfiguration -Identity "amartin" -AutoReplyState Enabled `
    -InternalMessage "Je suis actuellement absente, réponse à mon retour." `
    -ExternalMessage "Je suis actuellement absente, réponse à mon retour." `
    -ExternalAudience All
```

---

## 7. SharePoint Server

**1. Créer une collection de sites**
```powershell
Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

New-SPSite -Url "http://sharepoint.entreprise.local/sites/rh" `
    -OwnerAlias "ENTREPRISE\amartin" -Template "STS#3" -Name "Site RH"
```

**2. Bibliothèque de documents et liste personnalisée**
```powershell
$web = Get-SPWeb "http://sharepoint.entreprise.local/sites/rh"
$web.Lists.Add("Documents RH", "Bibliothèque de documents du service RH", [Microsoft.SharePoint.SPListTemplateType]::DocumentLibrary)
$web.Lists.Add("Suivi Congés", "Suivi des demandes de congés", [Microsoft.SharePoint.SPListTemplateType]::GenericList)
$web.Update()
```

**3. Ajouter des utilisateurs à un groupe SharePoint**
```powershell
$web = Get-SPWeb "http://sharepoint.entreprise.local/sites/rh"
$groupe = $web.Groups["Membres du site RH"]
$groupe.AddUser("ENTREPRISE\bdurand", "bdurand@entreprise.local", "Bob Durand", "Membre RH")
```

**4. Permissions différenciées sur deux bibliothèques**
```powershell
$web = Get-SPWeb "http://sharepoint.entreprise.local/sites/rh"
$listeLecture = $web.Lists["Documents RH"]
$listeLecture.BreakRoleInheritance($true)
$roleLecture = $web.RoleDefinitions["Lecture"]
$assignment = New-Object Microsoft.SharePoint.SPRoleAssignment("ENTREPRISE\GG_Techniciens", "", "", "")
$assignment.RoleDefinitionBindings.Add($roleLecture)
$listeLecture.RoleAssignments.Add($assignment)
$listeLecture.Update()
```

**5. Taille de quota utilisée par collection de sites**
```powershell
Get-SPSite -Limit All | Select-Object Url, `
    @{N="TailleUtiliseeMo";E={[math]::Round($_.Usage.Storage/1MB,2)}}, `
    @{N="QuotaMo";E={[math]::Round($_.Quota.StorageMaximumLevel/1MB,2)}}
```

**6. Activer une fonctionnalité (ex. corbeille / versionnement)**
```powershell
$web = Get-SPWeb "http://sharepoint.entreprise.local/sites/rh"
Enable-SPFeature -Identity "MetadataNavigation" -Url $web.Url

# Activer le versionnement sur une bibliothèque
$liste = $web.Lists["Documents RH"]
$liste.EnableVersioning = $true
$liste.Update()
```

**7. Sauvegarde et restauration d'une collection de sites**
```powershell
Backup-SPSite -Identity "http://sharepoint.entreprise.local/sites/rh" -Path "D:\Backups\rh.bak"

Restore-SPSite -Identity "http://sharepoint.entreprise.local/sites/rh_restore" `
    -Path "D:\Backups\rh.bak" -HostHeaderWebApplication "http://sharepoint.entreprise.local"
```

**8. Équivalent SharePoint Online avec PnP.PowerShell**
```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
Connect-PnPOnline -Url "https://entreprise.sharepoint.com/sites/rh" -Interactive

New-PnPList -Title "Documents RH" -Template DocumentLibrary
Add-PnPUserToGroup -LoginName "bdurand@entreprise.onmicrosoft.com" -Identity "Membres du site RH"
Set-PnPList -Identity "Documents RH" -EnableVersioning $true
```

---

### Notes
- Les noms de domaine, chemins, IP et noms de serveurs sont fictifs — à adapter à ton environnement de labo.
- Certaines cmdlets (Exchange, SharePoint on-prem) nécessitent d'être exécutées directement depuis le serveur ou via une session distante (`Enter-PSSession` / Exchange Management Shell), pas depuis un poste client standard.
- Pense à toujours utiliser `-WhatIf` avant une commande destructive (`Disable-ADAccount`, `Remove-*`, etc.) pour vérifier son effet avant de l'exécuter réellement.
