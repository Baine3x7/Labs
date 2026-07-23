<#
.SYNOPSIS
    Demande à l'utilisateur le nom d'une machine, récupère ses identifiants (Username, Password, IP, Port)
    dans un CSV, puis ouvre une session SSH interactive vers cette machine.

.DESCRIPTION
    Format du CSV attendu (colonnes) :
        Name,Username,Password,IP,Port
        SRV-AD,admin,MonMotDePasse1,192.168.0.180,2222
        CLIENTW11,user,MonMotDePasse2,192.168.0.180,2223

    Les VM sont derrière un NAT (WinNAT) sur l'hôte Hyper-V : IP = l'adresse externe de
    l'hôte (192.168.0.180), Port = le port externe mappé vers le port 22 de la VM via
    Add-NetNatStaticMapping. Chaque VM a donc son propre port externe.

    Le script :
        1. Affiche la liste des noms de machines disponibles dans le CSV.
        2. Demande à l'utilisateur de saisir le nom de la machine voulue.
        3. Retrouve la ligne correspondante (Username / Password / IP / Port).
        4. Lance une session SSH interactive vers $Username@$IP:$Port avec le mot de passe fourni automatiquement.

.PARAMETER CsvPath
    Chemin vers le fichier CSV (colonnes : Name, Username, Password, IP, Port).
    Par défaut : SSH.csv dans le même dossier que ce script.

.NOTES
    Nécessite plink.exe (fourni avec PuTTY) pour pouvoir fournir le mot de passe automatiquement
    tout en gardant une session interactive. Le ssh.exe natif de Windows ne permet pas de passer
    un mot de passe en paramètre pour une session interactive (par design, pour des raisons de sécurité).
    Télécharge PuTTY ici si besoin : https://www.putty.org/
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

# Vérifier que plink.exe est disponible
$Plink = Get-Command plink.exe -ErrorAction SilentlyContinue
if (-not $Plink) {
    Write-Warning "plink.exe introuvable dans le PATH. Installe PuTTY (https://www.putty.org/) pour la connexion automatique avec mot de passe."
    Write-Warning "Sans plink, tu peux te connecter manuellement avec : ssh <Username>@<IP> -p <Port> (mot de passe à saisir toi-même)."
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
$Port = $Machine.Port
$Password = $Machine.Password

Write-Host "`nConnexion à $ChoixMachine ($Username@$IpAddress`:$Port)..." -ForegroundColor Cyan

if ($Plink) {
    # Session interactive avec mot de passe fourni automatiquement
    & plink.exe -ssh "$Username@$IpAddress" -P $Port -pw $Password
}
else {
    # Repli : session SSH classique, mot de passe à saisir manuellement
    & ssh.exe -p $Port "$Username@$IpAddress"
}