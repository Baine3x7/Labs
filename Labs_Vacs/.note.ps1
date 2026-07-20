winget search Microsoft.VisualStudioCode
winget install Microsoft.VisualStudioCode

winget search --name github
winget install --id Git.Git -e --source winget
winget install GitHub.GitHubDesktop

 .\2.11.LABSP_Create.ps1
# .\2.11.LABSP_Create.ps1 : File D:\Temp\2.11.LABSP_Create.ps1 cannot be loaded because running scripts is disabled on
# this system. For more information, see about_Execution_Policies at https:/go.microsoft.com/fwlink/?LinkID=135170.
# At line:1 char:1
# + .\2.11.LABSP_Create.ps1
# + ~~~~~~~~~~~~~~~~~~~~~~~
#    + CategoryInfo          : SecurityError: (:) [], PSSecurityException
#    + FullyQualifiedErrorId : UnauthorizedAccess

powershell.exe -ExecutionPolicy Bypass -File .\2.11.LABSP_Create.ps1

#Premier boot en script (C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\2.11.LABSP_Create.ps1)
# - Arborescences mauvaise (Fix ligne 20 à 23)
# - Le client n'a pas fonctionné (Fix, le CSV ne contenait pas l'information OS)
# - Le nombre de proc ne s'est pas mis à jour (Fix la ligne pour le proco était manquante)
# - La machine client boot sur le HDD (Fix ligne 47 à 49)
# - La machine ne s'affiche pas automatiquement


Set-Location "..\$DirName\Client"

# Create the virtual hard disk
New-VHD -Path ".\SRV_Client-DISK1.vhdx" -SizeBytes $sizemain -Dynamic

# Create the VM
New-VM -Name $VMname `
       -Generation $gen `
       -MemoryStartupBytes $ram `
       -VHDPath ".\SRV_Client-DISK1.vhdx" `
       -Path "." `
       -SwitchName $switch

# Create the virtual hard disk
New-VHD -Path ".\SRV_Client-DISK1.vhdx" -SizeBytes $sizemain -Dynamic

# Create the VM
New-VM -Name $VMname `
       -Generation $gen `
       -MemoryStartupBytes $ram `
       -VHDPath ".\SRV_Client-DISK1.vhdx" `
       -Path "." `
       -SwitchName $switch

# Configure VM resources
Set-VMMemory -VMName $VMname -DynamicMemoryEnabled $false
Set-VMProcessor -VMName $VMname -Count $cpu
# Enable Secure Boot (recommended for Windows 11)
Set-VMFirmware -VMName $VMname -EnableSecureBoot On
# Configure the virtual TPM
Set-VMKeyProtector -VMName $VMname -NewLocalKeyProtector
Enable-VMTPM -VMName $VMname
# Attach the Windows 11 ISO
Add-VMDvdDrive -VMName $VMname -Path "D:\PARENT\Win11_25H2_English_x64_v2.iso"
# Set the DVD drive as the first boot device
$dvd = Get-VMDvdDrive -VMName $VMname
Set-VMFirmware -VMName $VMname -FirstBootDevice $dvd
# Start the VM
Start-VM -Name $VMname
# Give Hyper-V a few seconds to initialize the VM
Start-Sleep -Seconds 5
# Open the VM console
Start-Process "vmconnect.exe" -ArgumentList "localhost", $VMname
# Display running VMs
Get-VM | Where-Object { $_.State -eq "Running" }

Set-VMMemory -VMName $VMname -DynamicMemoryEnabled $false
Set-VMProcessor -VMName $VMname -Count $cpu
Set-VMFirmware -VMName $VMname -EnableSecureBoot On
Set-VMKeyProtector -VMName $VMname -NewLocalKeyProtector
Enable-VMTPM -VMName $VMname
Add-VMDvdDrive -VMName $VMname -Path "D:\PARENT\Win11_25H2_English_x64_v2.iso"
$dvd = Get-VMDvdDrive -VMName $VMname
Set-VMFirmware -VMName $VMname -FirstBootDevice $dvd
Start-VM -Name $VMname
Start-Sleep -Seconds 5
Start-Process "vmconnect.exe" -ArgumentList "localhost", $VMname
Get-VM | Where-Object { $_.State -eq "Running" }


# PS D:\Temp> powershell.exe -ExecutionPolicy Bypass -File .\2.21.LABSP_Config.ps1
#The credential is invalid.
#    + CategoryInfo          : OpenError: (SRV-AD:String) [], PSDirectException
#    + FullyQualifiedErrorId : PSSessionStateBroken

#PS D:\Temp> ^C                                                                                                          PS D:\Temp> ^C                                                                                                          PS D:\Temp> powershell.exe -ExecutionPolicy Bypass -File .\2.21.LABSP_Config.ps1                                        Element not found.                                                                                                          + CategoryInfo          : ObjectNotFound: (MSFT_NetIPAddress:ROOT/StandardCimv2/MSFT_NetIPAddress) [New-NetIPAddre     ss], CimException
#    + FullyQualifiedErrorId : Windows System Error 1168,New-NetIPAddress
#    + PSComputerName        : SRV-AD

#     No MSFT_DNSClientServerAddress objects found with property 'InterfaceAlias' equal to 'Ethernet'.  Verify the value of
#     the property and retry.                                                                                                     + CategoryInfo          : ObjectNotFound: (Ethernet:String) [Set-DnsClientServerAddress], CimJobException               + FullyQualifiedErrorId : CmdletizationQuery_NotFound_InterfaceAlias,Set-DnsClientServerAddress                         + PSComputerName        : SRV-AD                                                                                                                                                                                                            WARNING: The changes will take effect after you restart the computer WIN-S4RQH42561C.                                   No matching MSFT_NetAdapterBindingSettingData objects found by CIM query for instances of the                           ROOT/StandardCimv2/MSFT_NetAdapterBindingSettingData class on the  CIM server: SELECT * FROM                            MSFT_NetAdapterBindingSettingData  WHERE ((Name LIKE 'Ethernet')) AND ((ComponentID LIKE 'ms[_]tcpip6')). Verify query  parameters and retry.                                                                                                       + CategoryInfo          : ObjectNotFound: (MSFT_NetAdapterBindingSettingData:String) [Disable-NetAdapterBinding],      CimJobException                                                                                                          + FullyQualifiedErrorId : CmdletizationQuery_NotFound,Disable-NetAdapterBinding                                         + PSComputerName        : SRV-AD                                                                                                                                                                                                            Ok.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             PSComputerName : SRV-AD                                                                                                 RunspaceId     : 5f5f9b37-2efe-4188-9bbe-b50caeb0fe98                                                                   Success        : True                                                                                                   RestartNeeded  : No                                                                                                     FeatureResult  : {Active Directory Domain Services, Group Policy Management, Remote Server Administration Tools,                         Active Directory Administrative Center...}                                                             ExitCode       : Success                                                                                                                                                                                                                        PSComputerName : SRV-AD                                                                                                 RunspaceId     : 5f5f9b37-2efe-4188-9bbe-b50caeb0fe98                                                                   Success        : True                                                                                                   RestartNeeded  : No                                                                                                     FeatureResult  : {DNS Server, DNS Server Tools}                                                                         ExitCode       : Success                                                                                                                                                                                                                        WARNING: This computer has at least one physical network adapter that does not have static IP address(es) assigned to   its IP Properties. If both IPv4 and IPv6 are enabled for a network adapter, both IPv4 and IPv6 static IP addresses      should be assigned to both IPv4 and IPv6 Properties of the physical network adapter. Such static IP address(es)         assignment should be done to all the physical network adapters for reliable Domain Name System (DNS) operation.                                                                                                                                 WARNING: A delegation for this DNS server cannot be created because the authoritative parent zone cannot be found or it  does not run Windows DNS server. If you are integrating with an existing DNS infrastructure, you should manually       create a delegation to this DNS server in the parent zone to ensure reliable name resolution from outside the domain    "home.lan". Otherwise, no action is required.                                                                                                                                                                                                   WARNING: This computer has at least one physical network adapter that does not have static IP address(es) assigned to   its IP Properties. If both IPv4 and IPv6 are enabled for a network adapter, both IPv4 and IPv6 static IP addresses      should be assigned to both IPv4 and IPv6 Properties of the physical network adapter. Such static IP address(es)         assignment should be done to all the physical network adapters for reliable Domain Name System (DNS) operation.                                                                                                                                 WARNING: A delegation for this DNS server cannot be created because the authoritative parent zone cannot be found or it  does not run Windows DNS server. If you are integrating with an existing DNS infrastructure, you should manually       create a delegation to this DNS server in the parent zone to ensure reliable name resolution from outside the domain    "home.lan". Otherwise, no action is required.                                                                                                                                                                                                   PSComputerName : SRV-AD                                                                                                 RunspaceId     : 5f5f9b37-2efe-4188-9bbe-b50caeb0fe98
#     Message        : Operation completed successfully
#     Context        : DCPromo.General.3
#     RebootRequired : False
#     Status         : Success

#     Attempted to divide by zero.
#     At D:\Temp\2.21.LABSP_Config.ps1:58 char:13
#     +             $percent = ($i / $duration) * 100
#     +             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#         + CategoryInfo          : NotSpecified: (:) [], RuntimeException
#         + FullyQualifiedErrorId : RuntimeException



# Impossible d'acceder au serveur via le DNS
Restart le dns avec :
Restart-Service DNS

# Configuration similaire sur les pcs : 

scp `
>> "C:\Users\Baine\SynologyDrive\GitHub\Claude\ConfigPosteTravail.ps1"`
>> baine_vm@192.168.0.180:/D:/Temp/

 cd d:/Temp/
 powershell.exe -ExecutionPolicy Bypass ./ConfigPosteTravail.ps1


