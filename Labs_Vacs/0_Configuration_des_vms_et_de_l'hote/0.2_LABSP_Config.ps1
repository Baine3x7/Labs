$csv = Import-Csv ".\Config_VM.csv"

$cred_dom = Get-Credential -Message "Enter domain credential"

foreach ($element in $csv)
{
    $VMname = $element.VMname

    ## On redemande les identifiants de la VM à chaque itération
    $cred = Get-Credential -Title "Connexion VM" -Message "Entrer les identifiants pour la VM : $VMname"

    ### Récupération des informations du fichier CSV
    ## Configuration réseau, nom, fuseau horaire et firewall (commun à toutes les VMs)

    Invoke-Command -VMName $VMname -Credential $cred -ScriptBlock{  
        param  ($IPAddress,
                $Gateway,
                $DNS,
                $ComputerName,
                $Firewall)
        New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $Gateway
        Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $DNS
        Rename-Computer -NewName $ComputerName -Force
        Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6
        Set-TimeZone -Id "Romance Standard Time"
        netsh.exe advfirewall set allprofiles state $Firewall
        Restart-Computer -Force

    } -ArgumentList `
        $element.IPAddress,
        $element.Gateway,
        $element.DNS,
        $element.ComputerName,
        $element.Firewall


    ## Si la VM est un contrôleur de domaine, on installe les rôles ADDS et DNS, puis on crée le domaine
    if ($element.newforest -eq "yes")
    {
        $duration = 15
        for ($i = 0; $i -le $duration; $i++) {
            $percent = ($i / $duration) * 100

            Write-Progress `
                -Activity "Attente en cours..." `
                -Status "$i / $duration secondes" `
                -PercentComplete $percent

            Start-Sleep -Seconds 1
        }

        Write-Progress -Activity "Attente en cours..." -Completed

        Invoke-Command -VMName $VMname -Credential $cred -ScriptBlock{
            param ($Domain, $DomainOld)
            Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
            Start-Service sshd
            Set-Service -Name sshd -StartupType 'Automatic'
            New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
            Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
            Install-WindowsFeature -Name DNS -IncludeManagementTools
            Install-ADDSForest -DomainName $Domain -DomainNetbiosName $DomainOld -InstallDns -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -Force
        } -ArgumentList `
            $element.Domain,
            $element.Domainold

        $duration = 0 # a mettre a 300
        for ($i = 0; $i -le $duration; $i++)
        {
            $percent = ($i / $duration) * 100

            Write-Progress `
                -Activity "Attente en cours..." `
                -Status "$i / $duration secondes" `
                -PercentComplete $percent

            Start-Sleep -Seconds 1
        }

        ## Soft reset optionnel : ne garder que les OU de base (Domain Controllers) et le compte Administrateur
        ## Nécessite une colonne "SoftReset" (yes/no) dans le CSV
        if ($element.SoftReset -eq "yes")
        {
            Invoke-Command -VMName $VMname -Credential $cred -ScriptBlock{
                Import-Module ActiveDirectory

                $ousToDelete = Get-ADOrganizationalUnit -Filter * |
                    Where-Object { $_.Name -ne "Domain Controllers" }

                foreach ($ou in $ousToDelete)
                {
                    # Retire la protection sur l'OU et tout son contenu avant suppression
                    Get-ADObject -Filter * -SearchBase $ou.DistinguishedName -SearchScope Subtree -Properties ProtectedFromAccidentalDeletion |
                        Where-Object { $_.ProtectedFromAccidentalDeletion -eq $true } |
                        Set-ADObject -ProtectedFromAccidentalDeletion $false

                    Remove-ADOrganizationalUnit -Identity $ou.DistinguishedName -Recursive -Confirm:$false
                }
            }
        }
    }
    ## Si la VM est un serveur SharePoint ou SQL, on configure l'adresse IP, le nom de l'ordinateur, le firewall
    ## et on ajoute la machine au domaine
    else
    {
        $duration = 15
        for ($i = 0; $i -le $duration; $i++)
        {
            $percent = ($i / $duration) * 100

            Write-Progress `
                -Activity "Attente en cours..." `
                -Status "$i / $duration secondes" `
                -PercentComplete $percent

            Start-Sleep -Seconds 1
        }

        Write-Progress -Activity "Attente en cours..." -Completed

        Invoke-Command -VMName $VMname -Credential $cred -ScriptBlock{
            param ($Domain, $CredDom)
            Add-Computer -DomainName $Domain -Credential $CredDom -Force
            Restart-Computer
        } -ArgumentList $element.Domain, $cred_dom
    }
}