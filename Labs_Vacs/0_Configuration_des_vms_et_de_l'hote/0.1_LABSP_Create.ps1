$csv = Import-Csv ".\Create_VM.csv"
    
### Création du répertoire pour les VM
Set-Location ..\
#A modifier
New-Item -ItemType Directory -Name Lab_Vacs

foreach ($element in $csv)
{
    ### Récupération des informations du fichier CSV
    $vmname = $element.VMName
    $gen = $element.Gen
    $ram = [int64]::Parse($element.RAM.Trim()) * 1GB
    $switch = $element.Switch
    $cpu = [int64]::Parse($element.CPU.Trim()) * 1
    $os = $element.os
    $sizemain = [int64]::Parse($element.SizeMain.Trim()) * 1GB
    $sizesecond = [int64]::Parse($element.SizeSecond.Trim()) * 1GB
    $DirName = $element.DirName

    #A modifier
    Set-Location D:\Lab_Vacs 
    New-Item -ItemType Directory -Name $VMname
    Set-Location $VMname

    ### Vérification de l'existence du switch virtuel, sinon création
    try 
    {
        Get-VMSwitch -Name $switch  -ErrorAction Stop
    }
    catch [Microsoft.HyperV.PowerShell.VirtualizationException] 
    {
        New-VMSwitch -Name $switch -SwitchType Private
    }
    
    ### Création de la VM
    if($os -eq "client")
    {
        New-VHD -Path ".\SRV_Client-DISK1.vhdx" -SizeBytes $sizemain -Dynamic
        New-VM -Name $VMname `
       -Generation $gen `
       -MemoryStartupBytes $ram `
       -VHDPath ".\SRV_Client-DISK1.vhdx" `
       -Path "." `
       -SwitchName $switch
        Set-VMMemory -VMName $VMname -DynamicMemoryEnabled $false
        Set-VMProcessor -VMName $VMname -Count $cpu
        Set-VMFirmware -VMName $VMname -EnableSecureBoot On
        Set-VMKeyProtector -VMName $VMname -NewLocalKeyProtector
        Enable-VMTPM -VMName $VMname
        Add-VMDvdDrive -VMName $VMname -Path "D:\PARENT\Win11_25H2_English_x64_v2.iso"
        $dvd = Get-VMDvdDrive -VMName $VMname
        Set-VMFirmware -VMName $VMname -FirstBootDevice $dvd
        Start-VM -Name $VMname
        Start-Process "vmconnect.exe" -ArgumentList "localhost", $VMname
        Get-VM | Where-Object { $_.State -eq "Running" }
    }
    else
    {
        Set-Location ..\$DirName\$vmname
        New-VHD -Path ".\$VMname.vhdx" -SizeBytes $sizemain -Dynamic
        New-VHD -Path ".\$VMname-DISK1-DIFF.vhdx" -ParentPath "D:\PARENT\SYSPREP.vhdx" -Differencing
        New-VM -Name "$VMname" -Generation $gen -MemoryStartupBytes $ram -VHDPath ".\$VMname-DISK1-DIFF.vhdx" -Path .\ -SwitchName $switch
        Set-VMProcessor -VMName $VMname -Count $cpu
        Set-VMMemory -VMName "$VMname" -DynamicMemoryEnabled $false
        Start-VM -Name "$VMname"
        vmconnect.exe localhost "$VMname"
        Get-VM | Where-Object { $_.State -like "*Running*" }
    }
}