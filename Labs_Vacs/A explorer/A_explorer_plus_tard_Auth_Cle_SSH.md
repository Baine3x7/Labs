# À explorer plus tard — passage à l'authentification par clé SSH

Contexte : actuellement, `0.4_RemoteSSH.ps1` utilise un CSV avec mot de passe en clair
(`Name,Username,Password,IP,port`) + `plink -pw` pour se connecter aux VM via les ports
NAT mappés sur l'hôte (`192.168.0.180:2222`, `:2223`...). Ça reste acceptable pour un labo
purement interne à `home.lan`, mais si un jour tu veux fermer ce point faible (mot de passe
en clair sur disque), voici la démarche complète, prête à reprendre.

---

## 1. Pourquoi passer aux clés

- Plus de mot de passe stocké nulle part (ni clair, ni chiffré DPAPI — qui n'est de toute façon pas portable).
- Élimine le risque de brute-force sur les ports NAT exposés (2222, 2223...) même en interne.
- Le CSV devient versionnable (Git) sans risque, puisqu'il ne contient plus de secret.

---

## 2. Générer et déployer une clé par VM (une fois chacune)

```powershell
# Génère une paire de clés (ici sans passphrase, -N '""')
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\srv-ad_key" -N '""'

# Déploie la clé publique sur la VM, via le port NAT mappé de cette VM
type "$env:USERPROFILE\.ssh\srv-ad_key.pub" | ssh -p 2222 "HOME\tbaine"@192.168.0.180 "cat >> ~/.ssh/authorized_keys"
```

Répéter avec un nom de clé différent pour chaque VM (`clientw11_key`, port `2223`, etc.).

Si tu mets une passphrase sur la clé (recommandé même en labo), utilise `ssh-agent` pour
ne pas avoir à la retaper à chaque connexion :
```powershell
Start-Service ssh-agent
ssh-add "$env:USERPROFILE\.ssh\srv-ad_key"
```

---

## 3. Nouveau format du CSV (plus aucun secret dedans)

```csv
Name,Username,IP,Port,KeyPath
SRV-AD,HOME\tbaine,192.168.0.180,2222,C:\Users\Baine\.ssh\srv-ad_key
CLIENTW11,home.tbaine,192.168.0.180,2223,C:\Users\Baine\.ssh\clientw11_key
```

---

## 4. Script mis à jour

```powershell
<#
.SYNOPSIS
    Demande à l'utilisateur le nom d'une machine, récupère ses infos de connexion
    (Username, IP, Port, KeyPath) dans un CSV, puis ouvre une session SSH interactive
    via authentification par clé, à travers le mapping NAT (Add-NetNatStaticMapping).

.PARAMETER CsvPath
    Chemin vers le fichier CSV (colonnes : Name, Username, IP, Port, KeyPath).
    Par défaut : SSH.csv dans le même dossier que ce script.

.NOTES
    Aucun mot de passe stocké : authentification 100% par clé SSH.
#>

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
$Port = $Machine.Port
$KeyPath = $Machine.KeyPath

if (-not (Test-Path -Path $KeyPath)) {
    throw "Clé privée introuvable : $KeyPath"
}

Write-Host "`nConnexion à $ChoixMachine ($Username@$IpAddress`:$Port) via la clé $KeyPath..." -ForegroundColor Cyan

# Session SSH interactive, authentification par clé (aucun mot de passe en jeu)
& ssh.exe -i $KeyPath -p $Port "$Username@$IpAddress"
```

---

## 5. Durcissement optionnel du mapping NAT (à faire indépendamment du choix clé/mot de passe)

Restreindre les IP sources autorisées à se connecter sur les ports NAT (ex. seulement ta
machine de travail `.177`) :
```powershell
New-NetFirewallRule -DisplayName "Restrict SSH NAT 2222" -Direction Inbound -Protocol TCP -LocalPort 2222 -RemoteAddress 192.168.0.177 -Action Allow
New-NetFirewallRule -DisplayName "Restrict SSH NAT 2223" -Direction Inbound -Protocol TCP -LocalPort 2223 -RemoteAddress 192.168.0.177 -Action Allow
```

---

## 6. Rappel des limites déjà connues

- Le NAT (WinNAT) bloque tout trafic entrant non initié depuis les VM, y compris ICMP :
  pas de ping direct possible vers `192.168.100.x` depuis l'extérieur, quel que soit le
  mapping mis en place — seul le SSH (TCP, via port mappé) fonctionne.
- Double NAT en place : routeur (Internet ↔ home.lan) + Hyper-V (home.lan ↔ VM). Tant
  qu'aucune redirection de port n'est ajoutée sur le routeur vers `192.168.0.180:2222`/`2223`,
  ces ports restent invisibles depuis Internet — seulement accessibles depuis `home.lan`.
