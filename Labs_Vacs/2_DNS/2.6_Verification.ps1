<#
.CommandeStart
    powershell.exe -ExecutionPolicy bypass -File .\2.6_Verification.ps1 -ZoneName "home.lan" -CsvPath ".\Verification_DNS.csv"
.SYNOPSIS
    Vérifie, pour une liste de machines, si l'enregistrement DNS (A) existe déjà
    avant de le créer, afin d'éviter les doublons.

.DESCRIPTION
    Ce script s'appuie sur le module DnsServer (à exécuter sur le contrôleur de
    domaine / serveur DNS, ou via une session distante -ComputerName).
    Pour chaque machine de la liste, il :
      1. Recherche un enregistrement A existant portant le même nom dans la zone.
      2. S'il existe déjà avec la même IP -> ne fait rien (évite le doublon).
      3. S'il existe avec une IP différente -> avertit (conflit potentiel).
      4. S'il n'existe pas -> crée l'enregistrement A.

.PARAMETER ZoneName
    Nom de la zone DNS (ex: "home.lan").

.PARAMETER DnsServerName
    Nom du serveur DNS sur lequel exécuter les commandes (par défaut: local).

.PARAMETER Machines
    Tableau d'objets (Nom + IP) ou chemin vers un CSV (colonnes: Nom,IP).

.EXAMPLE
    .\2.6_Verification.ps1 -ZoneName "home.lan" -CsvPath ".\Verification_DNS.csv"

.EXAMPLE
    $liste = @(
        [PSCustomObject]@{Nom="SRV-SQL01"; IP="192.168.0.186"}
        [PSCustomObject]@{Nom="SRV-Exc01";  IP="192.168.0.187"}
    )
    .\2.6_Verification.ps1 -ZoneName "home.lan" -Machines $liste
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ZoneName,

    [string]$DnsServerName = $env:COMPUTERNAME,

    [Parameter(ParameterSetName = "Objets")]
    [PSCustomObject[]]$Machines,

    [Parameter(ParameterSetName = "Csv")]
    [string]$CsvPath
)

# --- Chargement de la liste des machines ---------------------------------
if ($CsvPath) {
    if (-not (Test-Path $CsvPath)) {
        Write-Error "Le fichier CSV '$CsvPath' est introuvable."
        return
    }
    $Machines = Import-Csv -Path $CsvPath
}

if (-not $Machines -or $Machines.Count -eq 0) {
    Write-Error "Aucune machine à traiter. Fournissez -Machines ou -CsvPath (colonnes: Nom,IP)."
    return
}

# --- Vérification du module DnsServer ------------------------------------
if (-not (Get-Module -ListAvailable -Name DnsServer)) {
    Write-Error "Le module DnsServer n'est pas disponible sur cette machine. Exécutez ce script sur le serveur DNS ou installez le module RSAT-DNS-Server."
    return
}
Import-Module DnsServer -ErrorAction Stop

# --- Traitement de chaque machine -----------------------------------------
foreach ($machine in $Machines) {

    $nom = $machine.Nom
    $ip  = $machine.IP

    if ([string]::IsNullOrWhiteSpace($nom) -or [string]::IsNullOrWhiteSpace($ip)) {
        Write-Warning "Entrée ignorée : Nom ou IP manquant ($machine)"
        continue
    }

    Write-Host "`n--- Traitement de '$nom' ($ip) ---" -ForegroundColor Cyan

    try {
        $enregistrementExistant = Get-DnsServerResourceRecord `
            -ZoneName $ZoneName `
            -Name $nom `
            -RRType A `
            -ComputerName $DnsServerName `
            -ErrorAction Stop
    }
    catch {
        # Get-DnsServerResourceRecord lève une erreur si aucun enregistrement trouvé
        $enregistrementExistant = $null
    }

    if ($enregistrementExistant) {

        $ipExistante = $enregistrementExistant.RecordData.IPv4Address.IPAddressToString

        if ($ipExistante -eq $ip) {
            Write-Host "Enregistrement déjà présent avec la même IP ($ip) -> aucune action." -ForegroundColor Yellow
        }
        else {
            Write-Warning "Conflit : '$nom' existe déjà avec l'IP $ipExistante (demandée: $ip). Aucune modification effectuée."
        }
        continue
    }

    # --- Création de l'enregistrement s'il n'existe pas ---
    try {
        Add-DnsServerResourceRecordA `
            -ZoneName $ZoneName `
            -Name $nom `
            -IPv4Address $ip `
            -ComputerName $DnsServerName `
            -ErrorAction Stop

        Write-Host "Enregistrement créé : $nom -> $ip" -ForegroundColor Green
    }
    catch {
        Write-Error "Échec de la création de l'enregistrement pour '$nom' : $_"
    }
}

Write-Host "`nTraitement terminé." -ForegroundColor Cyan