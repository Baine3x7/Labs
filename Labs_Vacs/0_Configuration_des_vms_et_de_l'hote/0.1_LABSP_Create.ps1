### ============================================================
### Configuration - a adapter selon l'environnement
### ============================================================
$CsvPath            = ".\Create_VM.csv"
$VmRootPath         = "D:\Lab_Vacs"
$IsoWin11Path       = "D:\PARENT\Win11_25H2_English_x64_v2.iso"
$IsoWinServ2025Path = "D:\PARENT\WinServer2025.iso"
$SysprepWS2025Path  = "D:\PARENT\SYSPREP.vhdx"

$csv = Import-Csv $CsvPath

### Creation du repertoire racine des VM (si absent)
if (-not (Test-Path $VmRootPath))
{
    New-Item -ItemType Directory -Path $VmRootPath | Out-Null
}

foreach ($element in $csv)
{
    ### Recuperation des informations du fichier CSV
    $vmname     = $element.VMName
    $gen        = $element.Gen
    $ram        = [int64]::Parse($element.RAM.Trim()) * 1GB
    $switches   = $element.Switch -split ';' | ForEach-Object { $_.Trim() }
    $cpu        = [int64]::Parse($element.CPU.Trim())
    $os         = $element.OS.Trim()
    $sizemain   = [int64]::Parse($element.SizeMain.Trim()) * 1GB
    $sizesecond = [int64]::Parse($element.SizeSecond.Trim()) * 1GB

    ### Si la VM existe deja, on ne la recree pas
    if (Get-VM -Name $vmname -ErrorAction SilentlyContinue)
    {
        Write-Host "La VM '$vmname' existe deja, creation ignoree." -ForegroundColor Yellow
        continue
    }

    ### Preparation du repertoire de la VM
    $vmPath = Join-Path $VmRootPath $vmname
    New-Item -ItemType Directory -Path $vmPath -Force | Out-Null
    Set-Location $vmPath

    ### Verification / creation des switches virtuels necessaires (1 ou 2)
    foreach ($sw in $switches)
    {
        if (-not (Get-VMSwitch -Name $sw -ErrorAction SilentlyContinue))
        {
            New-VMSwitch -Name $sw -SwitchType Private
        }
    }

    ### Creation du disque + de la VM selon le mode d'installation demande
    switch ($os)
    {
        "SysprepWS2025"
        {
            ### Disque differencie a partir du parent syspreppe
            New-VHD -Path ".\$vmname-DISK1-DIFF.vhdx" -ParentPath $SysprepWS2025Path -Differencing | Out-Null
            New-VM -Name $vmname -Generation $gen -MemoryStartupBytes $ram `
                -VHDPath ".\$vmname-DISK1-DIFF.vhdx" -Path "." -SwitchName $switches[0] | Out-Null
        }
        "IsoWin11"
        {
            New-VHD -Path ".\$vmname-DISK1.vhdx" -SizeBytes $sizemain -Dynamic | Out-Null
            New-VM -Name $vmname -Generation $gen -MemoryStartupBytes $ram `
                -VHDPath ".\$vmname-DISK1.vhdx" -Path "." -SwitchName $switches[0] | Out-Null
            Set-VMFirmware -VMName $vmname -EnableSecureBoot On
            Set-VMKeyProtector -VMName $vmname -NewLocalKeyProtector
            Enable-VMTPM -VMName $vmname
            Add-VMDvdDrive -VMName $vmname -Path $IsoWin11Path
            $dvd = Get-VMDvdDrive -VMName $vmname
            Set-VMFirmware -VMName $vmname -FirstBootDevice $dvd
        }
        "IsoWinServ2025"
        {
            New-VHD -Path ".\$vmname-DISK1.vhdx" -SizeBytes $sizemain -Dynamic | Out-Null
            New-VM -Name $vmname -Generation $gen -MemoryStartupBytes $ram `
                -VHDPath ".\$vmname-DISK1.vhdx" -Path "." -SwitchName $switches[0] | Out-Null
            Add-VMDvdDrive -VMName $vmname -Path $IsoWinServ2025Path
            $dvd = Get-VMDvdDrive -VMName $vmname
            Set-VMFirmware -VMName $vmname -FirstBootDevice $dvd
        }
        default
        {
            ### Colonne OS vide ou "Null" -> disque vierge, pas d'OS installe
            New-VHD -Path ".\$vmname-DISK1.vhdx" -SizeBytes $sizemain -Dynamic | Out-Null
            New-VM -Name $vmname -Generation $gen -MemoryStartupBytes $ram `
                -VHDPath ".\$vmname-DISK1.vhdx" -Path "." -SwitchName $switches[0] | Out-Null
        }
    }

    ### Configuration CPU / memoire (commune a tous les cas)
    Set-VMProcessor -VMName $vmname -Count $cpu
    Set-VMMemory -VMName $vmname -DynamicMemoryEnabled $false

    ### Ajout d'une 2e carte reseau si un 2e switch est precise dans le CSV
    ### (colonne Switch au format "Switch1;Switch2")
    if ($switches.Count -gt 1)
    {
        Add-VMNetworkAdapter -VMName $vmname -SwitchName $switches[1]
    }

    ### Demarrage de la VM
    Start-VM -Name $vmname
    Start-Process "vmconnect.exe" -ArgumentList "localhost", $vmname
}

Get-VM | Where-Object { $_.State -eq "Running" }