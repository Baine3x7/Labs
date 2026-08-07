<#
.SYNOPSIS
    Demande à l'utilisateur le nom d'une machine, récupère ses infos de connexion (Username, IP, KeyPath)
    dans un CSV, puis ouvre une session SSH interactive via authentification par clé.

.DESCRIPTION
    Format du CSV attendu (colonnes, aucune donnée sensible dedans) :
        Name,Username,IP,KeyPath
        SRV-AD,admin,192.168.100.10,C:\Users\Baine\.ssh\srv-ad_key
        CLIENTW11,user,192.168.100.11,C:\Users\Baine\.ssh\clientw11_key

    Le script :
        1. Affiche la liste des noms de machines disponibles dans le CSV.
        2. Demande à l'utilisateur de saisir le nom de la machine voulue.
        3. Retrouve la ligne correspondante (Username / IP / KeyPath).
        4. Lance une session SSH interactive avec la clé privée correspondante.

    Aucun mot de passe n'est stocké, ni en clair ni chiffré : l'authentification repose
    entièrement sur la paire de clés SSH déployée au préalable sur chaque machine.

.PARAMETER CsvPath
    Chemin vers le fichier CSV (colonnes : Name, Username, IP, KeyPath).
    Par défaut : SSH.csv dans le même dossier que ce script.

.NOTES
    Prérequis, à faire une fois par machine :
        ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\<nom>_key" -N '""'
        type "$env:USERPROFILE\.ssh\<nom>_key.pub" | ssh <user>@<ip> "cat >> ~/.ssh/authorized_keys"

    Si tes clés sont protégées par une passphrase, utilise ssh-agent pour éviter
    de la retaper à chaque connexion :
        Start-Service ssh-agent
        ssh-add "$env:USERPROFILE\.ssh\<nom>_key"
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

# Afficher la liste des machines disponibles
Write-Host "Machines disponibles :" -ForegroundColor Cyan
$Machines | ForEach-Object { Write-Host "  - $($_.Name)" }

# Demander à l'utilisateur quelle machine il veut
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

# Session SSH interactive, authentification par clé (aucun mot de passe en jeu)
& ssh.exe -i $KeyPath "$Username@$IpAddress"
