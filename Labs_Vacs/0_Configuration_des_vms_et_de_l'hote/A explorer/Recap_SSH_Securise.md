# Connexion SSH sécurisée aux VM du labo — récapitulatif

## Principe

Remplacement du stockage de mots de passe en clair (ou chiffré DPAPI) par une **authentification par clé SSH**. Le fichier `SSH.csv` ne contient plus aucun secret — uniquement des chemins vers des clés privées locales.

---

## 1. Prérequis — générer et déployer une clé par machine

À faire une fois par VM :

```powershell
# Générer une paire de clés (ici sans passphrase, -N '""')
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\<nom>_key" -N '""'

# Déployer la clé publique sur la VM cible
type "$env:USERPROFILE\.ssh\<nom>_key.pub" | ssh <user>@<ip> "cat >> ~/.ssh/authorized_keys"
```

Si tes clés sont protégées par une passphrase, utilise `ssh-agent` pour éviter de la retaper à chaque connexion (la passphrase n'est alors jamais écrite sur disque) :
```powershell
Start-Service ssh-agent
ssh-add "$env:USERPROFILE\.ssh\<nom>_key"
```

---

## 2. Format du CSV — `SSH.csv`

Aucune donnée sensible dedans (nom, utilisateur, IP, chemin de clé uniquement) :

```csv
Name,Username,IP,KeyPath
SRV-AD,admin,192.168.100.10,C:\Users\Baine\.ssh\srv-ad_key
CLIENTW11,user,192.168.100.11,C:\Users\Baine\.ssh\clientw11_key
```

Doit se trouver dans le **même dossier** que le script `Connect-VMByName.ps1` (chemin par défaut).

---

## 3. Script — `Connect-VMByName.ps1`

```powershell
[CmdletBinding()]
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot "SSH.csv")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $CsvPath)) {
    throw "Fichier CSV introuvable : $CsvPath"
}

$Machines = Import-Csv -Path $CsvPath

if (-not $Machines) {
    throw "Le CSV est vide ou mal formaté."
}

Write-Host "Machines disponibles :" -ForegroundColor Cyan
$Machines | ForEach-Object { Write-Host "  - $($_.Name)" }

$ChoixMachine = Read-Host "`nSur quelle machine souhaitez-vous vous connecter ?"

$Machine = $Machines | Where-Object { $_.Name -eq $ChoixMachine }

if (-not $Machine) {
    throw "Aucune machine nommée '$ChoixMachine' trouvée dans le CSV."
}

$Username = $Machine.Username
$IpAddress = $Machine.IP
$KeyPath = $Machine.KeyPath

if (-not (Test-Path -Path $KeyPath)) {
    throw "Clé privée introuvable : $KeyPath"
}

Write-Host "`nConnexion à $ChoixMachine ($Username@$IpAddress) via la clé $KeyPath..." -ForegroundColor Cyan

& ssh.exe -i $KeyPath "$Username@$IpAddress"
```

Usage :
```powershell
.\Connect-VMByName.ps1
```
(ou `-CsvPath` pour pointer vers un autre fichier)

---

## 4. Ce que ça change concrètement

- Plus aucun mot de passe stocké, ni en clair ni chiffré — l'authentification repose entièrement sur la paire de clés déployée au préalable.
- Le CSV peut être versionné (ex. dépôt Git de labo) sans risque, puisqu'il ne contient plus de secret.
- La sécurité se déplace vers la protection des fichiers de clés privées eux-mêmes (`.ssh\*_key`) — vérifier que les permissions NTFS de `%USERPROFILE%\.ssh` restent restreintes à l'utilisateur.
- Si passphrase sur les clés : passer par `ssh-agent` pour ne jamais la taper/stocker en clair.

---

## Historique des étapes précédentes (pour contexte)

1. Script initial avec credentials en argument direct (`plink -pw`) — écarté car mot de passe visible dans la liste des processus.
2. Script avec CSV (`Username,Password,IP`) + Posh-SSH — mot de passe en `SecureString` en mémoire, mais CSV en clair sur disque.
3. Option de chiffrement DPAPI (`ConvertFrom-SecureString`) évoquée mais écartée — non portable entre PC/utilisateurs.
4. **Solution retenue** : authentification par clé SSH, CSV sans secret (ce document).
