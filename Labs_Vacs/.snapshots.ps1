<#
.SYNOPSIS
    Creates a checkpoint (snapshot) for every Hyper-V VM present on the host.

.DESCRIPTION
    Loops through all VMs returned by Get-VM (regardless of state: Running,
    Off, Saved...) and creates a named checkpoint for each one, timestamped
    at execution time. Logs success/failure per VM to the console.

.NOTES
    Must be run with administrator privileges, on a machine with the
    Hyper-V PowerShell module installed (Hyper-V role or RSAT tools).
#>

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

param(
    [string]$Prefix = "AutoSnap"
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$snapshotName = "$Prefix`_$timestamp"

$vms = Get-VM

if (-not $vms) {
    Write-Warning "Aucune VM trouvée sur cet hôte."
    return
}

Write-Host "Création du snapshot '$snapshotName' pour $($vms.Count) VM(s)..." -ForegroundColor Cyan

foreach ($vm in $vms) {
    try {
        Checkpoint-VM -VMName $vm.Name -SnapshotName $snapshotName
        Write-Host "[OK] $($vm.Name) -> snapshot '$snapshotName' créé." -ForegroundColor Green
    }
    catch {
        Write-Host "[ECHEC] $($vm.Name) -> $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Terminé." -ForegroundColor Cyan