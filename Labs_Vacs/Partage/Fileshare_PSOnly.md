# Commandes utilisées — Partage réseau VM / AD

Référence commentée de toutes les commandes PowerShell/CMD utilisées pendant l'exercice.

---

## 1. Identité et connexion

```powershell
whoami
```
Affiche `machine\utilisateur` (ou `domaine\utilisateur`). Le nom d'utilisateur est la partie après le `\`.

```bash
ssh Administrator@home.lan
```
Connexion SSH vers la VM/DC en tant qu'Administrateur.

---

## 2. Activer OpenSSH Server (côté Windows, pour permettre le SCP)

```powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
```
Liste les composants OpenSSH disponibles et leur état (`Installed` / `NotPresent`).

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```
Installe le serveur OpenSSH.

```powershell
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
```
Démarre le service SSH et le configure pour démarrer automatiquement.

```powershell
Get-NetFirewallRule -Name *ssh*
```
Vérifie que la règle de pare-feu autorisant SSH existe.

```powershell
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```
Crée manuellement la règle de pare-feu si elle n'existe pas.

```cmd
ipconfig
```
Récupère l'adresse IPv4 de la machine.

---

## 3. Créer le dossier et le partage réseau (sur la VM)

```powershell
New-Item -Path "D:\Workgroup" -ItemType Directory -Force
```
Crée le dossier à partager (`-Force` évite une erreur si le dossier existe déjà).

```powershell
New-SmbShare -Name "Workgroup" -Path "D:\Workgroup" -FullAccess "Everyone" -ChangeAccess "Everyone" -ReadAccess "Everyone"
```
Crée le partage SMB avec accès complet pour tout le monde (permissions **réseau** uniquement).

```powershell
icacls "D:\Workgroup" /grant "Everyone:(OI)(CI)F"
```
Ajoute les permissions **NTFS** correspondantes (indispensable en plus du partage réseau — sans ça, l'accès réseau seul ne suffit pas).

```powershell
Get-SmbShare -Name "Workgroup"
```
Vérifie qu'un partage existe et affiche ses propriétés (nom, chemin, description).

```powershell
Get-SmbShare -Name "Workgroup" | Select Name, Path, ShareType
```
Vérifie en particulier le `ShareType` (doit être `FileSystemDirectory`).

```powershell
Get-Service -Name LanmanServer
```
Vérifie que le service "Serveur" (partage de fichiers) est bien démarré — sans lui, aucun partage n'est accessible.

⚠️ **Piège rencontré** : `Get-SmbShare` sans paramètre interroge toujours la **machine locale**. Pour vérifier un partage sur une machine distante, il faut soit s'y connecter directement, soit utiliser `-CimSession` ou `Invoke-Command`.

---

## 4. Créer un utilisateur AD partagé

```powershell
New-ADUser -Name "BainePartage" -GivenName "Baine" -Surname "Partage" `
    -SamAccountName "pbaine" -UserPrincipalName "pbaine@home.lan" `
    -Path "OU=OU_Users,DC=home,DC=lan" -Enabled $true `
    -AccountPassword (ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force) `
    -PasswordNeverExpires $true -ChangePasswordAtLogon $false
```
Crée le compte AD. `-PasswordNeverExpires $true` est important pour un compte partagé, afin d'éviter un blocage d'authentification imprévu quand le mot de passe expire.

```powershell
Get-ADUser -Identity "pbaine" -Properties Enabled, LockedOut, PasswordExpired, PasswordLastSet, PasswordNeverExpires
```
Vérifie l'état du compte : activé, verrouillé, mot de passe expiré, etc.

```powershell
Unlock-ADAccount -Identity "pbaine"
```
Déverrouille le compte si `LockedOut` est `True`.

```powershell
Set-ADAccountPassword -Identity "pbaine" -Reset -NewPassword (ConvertTo-SecureString 'Pa$$w0rd!' -AsPlainText -Force)
```
Réinitialise le mot de passe du compte (utile pour éliminer tout doute sur la valeur réellement enregistrée).

```powershell
Set-ADUser -Identity "pbaine" -ChangePasswordAtLogon $false -PasswordNeverExpires $true
```
Ajuste les propriétés du compte après création.

---

## 5. Mapper le lecteur réseau (sur un PC client)

```powershell
New-PSDrive -Name "W" -PSProvider FileSystem -Root "\\192.168.0.185\Workgroup" -Persist
```
Mappe le partage en lecteur `W:`. `-Persist` rend le mapping visible dans l'Explorateur et persistant après reboot. **Ne mappe que sur la machine où la commande est exécutée** — pour tous les PC, il faut passer par une GPO.

```powershell
$securePass = ConvertTo-SecureString 'Pa$$w0rd' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential('HOME\pbaine', $securePass)
New-PSDrive -Name "W" -PSProvider FileSystem -Root "\\192.168.0.185\Workgroup" -Persist -Credential $cred
```
Construit l'objet credential directement en code plutôt que via `Get-Credential` (contourne le bug de fenêtre de connexion qui disparaît instantanément).

⚠️ **Piège rencontré** : le format du nom d'utilisateur doit utiliser le nom **NetBIOS** du domaine (`HOME\pbaine`), pas le nom DNS (`home.lan\pbaine`). Le format UPN (`pbaine@home.lan`) fonctionne aussi et évite cette ambiguïté.

```cmd
net use W: \\192.168.0.185\Workgroup Pa$$w0rd /user:HOME\pbaine /persistent:yes
```
Équivalent CMD à `New-PSDrive`, utile pour isoler un éventuel bug spécifique à PowerShell.

```cmd
net use
```
Liste toutes les connexions réseau actives (lecteurs mappés).

```cmd
net use \\192.168.0.185 /delete
net use W: /delete /y
net use * /delete /y
```
Supprime une connexion réseau existante (spécifique, ou toutes). Utile en cas de conflit d'identifiants sur le même serveur.

```powershell
Get-SmbMapping
```
Liste les mappings SMB actifs côté PowerShell (équivalent moderne, montre aussi les mappings "fantômes").

```powershell
Remove-SmbMapping -RemotePath "\\192.168.0.185\Workgroup" -Force
```
Supprime un mapping SMB existant/bloqué.

```powershell
cmdkey /list
```
Liste tous les identifiants réseau mis en cache sur la machine — utile pour détecter un conflit d'authentification avec un ancien compte.

```powershell
cmdkey /delete:192.168.0.185
```
Supprime une entrée d'identifiants en cache pour une cible spécifique.

---

## 6. Diagnostic réseau

```powershell
Test-Connection -ComputerName 192.168.0.185
```
Ping basique — attention à toujours vérifier la colonne `Source`, pour être sûr de tester depuis la bonne machine.

```powershell
Test-NetConnection -ComputerName 192.168.0.185 -Port 445
```
Teste spécifiquement l'accessibilité du port SMB (445). `TcpTestSucceeded: True` confirme que le réseau/pare-feu n'est pas en cause.

```powershell
hostname
```
Affiche le nom de la machine locale — utile pour confirmer depuis quelle machine une commande est réellement exécutée.

```powershell
nslookup home.lan
Resolve-DnsName home.lan
```
Vérifie la résolution DNS du nom de domaine.

```cmd
net view \\192.168.0.185
```
Liste les partages visibles sur une machine distante (nécessite une énumération autorisée — un "Access is denied" ici ne signifie pas forcément qu'aucun partage n'existe).

---

## 7. Pare-feu et profil réseau (côté VM)

```powershell
Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" | Select DisplayName, Enabled
Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True
```
Vérifie/active les règles de pare-feu nécessaires au partage de fichiers.

```powershell
Get-NetConnectionProfile
Set-NetConnectionProfile -InterfaceAlias "Ethernet" -NetworkCategory Private
```
Le profil réseau **Public** bloque le partage de fichiers par défaut — le passer en **Private** débloque le partage.

---

## 8. Gestion de domaine à distance (RSAT / GPO)

```powershell
Get-WindowsCapability -Name RSAT.GroupPolicy* -Online | Add-WindowsCapability -Online
```
Installe les outils RSAT (console GPMC + module PowerShell `GroupPolicy`) sur un PC non-DC.

```powershell
Get-Module -ListAvailable GroupPolicy
```
Vérifie que le module GPO est bien disponible après installation de RSAT.

```powershell
New-GPO -Name "Mapping-Workgroup" -Comment "Mappe le lecteur W vers le partage VM"
```
Crée une nouvelle GPO.

```powershell
New-GPLink -Name "Mapping-Workgroup" -Target "OU=OU_PC,DC=home,DC=lan"
```
Lie la GPO à l'OU contenant les PC clients.

```powershell
Get-ADDomain | Select NetBIOSName, DNSRoot
Get-ADDomain -Server 192.168.0.185
```
Récupère les informations du domaine (nom NetBIOS, nom DNS). Le paramètre `-Server` permet de cibler explicitement le DC si la découverte automatique échoue (erreur ADWS).

```powershell
Get-Service ADWS
Start-Service ADWS
Set-Service ADWS -StartupType Automatic
```
Vérifie/démarre le service Active Directory Web Services, requis pour que les cmdlets `Get-AD*`/`New-AD*` fonctionnent à distance.

```powershell
Get-ADGroupMember -Identity "Group Policy Creator Owners"
```
Vérifie qui a le droit de créer/modifier des GPO.

---

## 9. Divers

```powershell
$PSVersionTable.PSVersion
```
Affiche la version de PowerShell utilisée — utile pour écarter certains bugs connus spécifiques à PS7.

```powershell
Test-Path "\\192.168.0.185\Workgroup"
```
Teste l'accessibilité d'un chemin UNC sans le mapper.