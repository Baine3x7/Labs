# Résumé — Troubleshooting partage réseau VM / AD

## Objectif de l'exercice

Créer un dossier de partage sur la VM (accessible sur tous les PC de travail), mapper le lecteur sur tous les postes, et créer un utilisateur AD partagé permettant à tout le monde de se connecter.

**Contrainte** : tout gérer depuis le PC main (Win11 Pro "Baine"), sans intervention manuelle directe sur chaque poste.

**Topologie découverte en cours de route** :
- PC main : `BAINE` (Win11 Pro), IP `192.168.0.177`
- VM : `SRV-AD` (`home.lan`), IP `192.168.0.185` — **également contrôleur de domaine** (confirmé par la présence des partages `NETLOGON`/`SYSVOL`)
- Domaine AD : `home.lan`, NetBIOS `HOME`, mode `Windows2025Domain`

---

## 1. Trouver son nom d'utilisateur

`whoami` renvoie `machine\utilisateur` — le nom d'utilisateur est la partie après le `\`.

## 2. Activer OpenSSH Server sur Windows (pour SCP)

- Vérifier l'installation : `Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'`
- Installer : `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0`
- Démarrer et activer au démarrage : `Start-Service sshd` / `Set-Service sshd -StartupType Automatic`
- Vérifier la règle de pare-feu : `Get-NetFirewallRule -Name *ssh*`
- Récupérer l'IP avec `ipconfig`

## 3. Script initial de partage (revue et corrections)

Le script fourni mélangeait des commandes destinées à des machines différentes :

| Commande | Machine cible |
|---|---|
| `New-Item`, `New-SmbShare` | La VM (hébergeant `D:\Workgroup`) |
| `New-ADUser` | Le contrôleur de domaine |
| `New-PSDrive` | Chaque PC client (ou via GPO) |

Corrections apportées :
- Ajout des permissions **NTFS** en plus des permissions de partage réseau (`icacls "D:\Workgroup" /grant "Everyone:(OI)(CI)F"`), car `New-SmbShare` ne gère que l'accès réseau.
- `New-ADUser` corrigé avec `-PasswordNeverExpires $true -ChangePasswordAtLogon $false`, utile pour un compte partagé.
- Mapper le lecteur sur *tous* les PC nécessite une **GPO** (Group Policy Preference "Mapped Drives"), pas un `New-PSDrive` lancé une seule fois sur une seule machine.

## 4. GPO à distance depuis un PC non-DC

Puisque le PC main est une machine séparée du DC :
- Installer RSAT - GPMC : `Get-WindowsCapability -Name RSAT.GroupPolicy* -Online | Add-WindowsCapability -Online`
- Créer et lier la GPO à distance :
  ```powershell
  New-GPO -Name "Mapping-Workgroup"
  New-GPLink -Name "Mapping-Workgroup" -Target "OU=OU_PC,DC=home,DC=lan"
  ```
- Le mapping de lecteur lui-même se configure via l'éditeur GPO (Préférences → Mappages de lecteurs), pas en pur PowerShell.
- Nécessite d'être membre de **Group Policy Creator Owners** ou **Domain Admins**.

## 5. Long troubleshooting de `New-PSDrive` / `net use`

Erreurs rencontrées dans l'ordre, et diagnostic associé :

1. **"The network name cannot be found"**
   → Un premier `Test-Connection`/`Test-NetConnection` avait en fait été lancé *depuis* la VM elle-même (source = destination), donc ne testait rien du tout. Une fois relancé depuis le vrai PC main (`BAINE`, IP `.177`), le port 445 répondait bien (`TcpTestSucceeded: True`) — le réseau n'était pas en cause.

2. **Fenêtre `Get-Credential` qui disparaît instantanément**
   → Contourné en construisant l'objet `PSCredential` directement en code plutôt que via la boîte de dialogue :
   ```powershell
   $securePass = ConvertTo-SecureString 'motdepasse' -AsPlainText -Force
   $cred = New-Object System.Management.Automation.PSCredential('DOMAINE\utilisateur', $securePass)
   ```

3. **"The network resource type is not correct"**
   → Plusieurs pistes explorées : mappings SMB fantômes (`Get-SmbMapping`/`Remove-SmbMapping`), connexions existantes en conflit (`net use`, `cmdkey /list` — aucune entrée trouvée pour la VM), bug connu de `New-PSDrive -Persist` sous PowerShell 7 (écarté : la machine était en PS 5.1), et format NetBIOS incorrect dans les identifiants (`home.lan\pbaine` au lieu de `HOME\pbaine`, confirmé via `Get-ADDomain`).

4. **`Get-ADDomain` : "Unable to find a default server with Active Directory Web Services running"**
   → Résolu en ciblant explicitement le DC : `Get-ADDomain -Server 192.168.0.185`.

5. **Partage introuvable — cause racine réelle**
   → `Get-SmbShare` lancé sur le PC main (BAINE) au lieu de la VM ne montrait que les partages admin locaux. Une fois vérifié **directement sur la VM**, le partage `Workgroup` **n'existait pas du tout** (jamais créé, ou perdu en cours de route). Recréé avec succès :
   ```powershell
   New-Item -Path "D:\Workgroup" -ItemType Directory -Force
   New-SmbShare -Name "Workgroup" -Path "D:\Workgroup" -FullAccess "Everyone"
   icacls "D:\Workgroup" /grant "Everyone:(OI)(CI)F"
   ```

6. **Cause finale de l'échec de connexion : mauvais mot de passe / mauvais utilisateur**
   → Après avoir corrigé le partage manquant, il restait une erreur d'authentification. Résolu en changeant d'utilisateur pour un compte dont le mot de passe était connu avec certitude.

## 6. Enseignements clés

- Toujours vérifier **depuis quelle machine** une commande de diagnostic réseau est réellement exécutée (`hostname`, ou comparer Source/Destination dans `Test-Connection`).
- `Get-SmbShare` sans paramètre interroge toujours la **machine locale** — pour vérifier un partage distant, se connecter à la machine cible ou utilisation `-CimSession`/`Invoke-Command`.
- L'erreur générique **"The network resource type is not correct"** peut avoir de nombreuses causes (mapping fantôme, bug PS7, partage inexistant, mauvais format de domaine) — il faut éliminer les hypothèses une par une.
- Un compte de service/partage AD doit être configuré avec `-PasswordNeverExpires $true` pour éviter les blocages d'authentification imprévus.
- Le format des identifiants (`NETBIOS\utilisateur` vs `nom.dns\utilisateur` vs `utilisateur@upn`) compte — le NetBIOS se vérifie avec `Get-ADDomain | Select NetBIOSName`.

## 7. Prochaines étapes (non traitées à date de ce résumé)

- Configurer la GPO de mapping de lecteur pour la déployer sur tous les PC clients (via l'éditeur GPO, préférence "Mapped Drives").
- Revalider le mot de passe définitif du compte `pbaine` à documenter/distribuer pour l'exercice.