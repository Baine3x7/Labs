$csv = Import-Csv ".\*Config_VM.csv"

# $cred = Get-Credential
$cred_dom = Get-Credential -Message "Enter domain credential"
foreach ($element in $csv)
{
    $VMname = $element.VMname
    ### Récupération des informations du fichier CSv
    ## Si la VM est un contrôleur de domaine, on installe les rôles ADDS et DNS, puis on crée le domaine Sharepoint.lan

         Invoke-Command -VMName $VMname -Credential $cred -ScriptBlock{  
            param  ($IPAddress,
                    $Gateway,
                    $DNS,
                    $ComputerName,
                    $Firewall)
        New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $ipaddress -PrefixLength 24 -DefaultGateway $Gateway
        Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $DNS
        Rename-Computer -NewName $computername -Force
        Disable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6
        Set-TimeZone -Id "Romance Standard Time"
        netsh.exe advfirewall set allprofiles state $firewall
        Restart-Computer -Force

        }-ArgumentList `
        $element.IPAddress,
        $element.Gateway,
        $element.DNS,
        $element.ComputerName,
        $element.Firewall

    
    if ($element.newforest -eq "yes")
    {  $duration = 30
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
        param  ($Domain)  
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        Install-WindowsFeature -Name DNS -IncludeManagementTools
        Install-ADDSForest -DomainName "$domain" -DomainNetbiosName "$domainold" -InstallDns -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -Force      
        }-argumentList `
        $element.Domain

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
    }
    ## Si la VM est un serveur SharePoint ou SQL, on configure l'adresse IP, le nom de l'ordinateur, le firewall et on ajoute la machine au domaine Sharepoint.lan
    else
    {       
        $duration = 30
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
        param  ($Domain) 
        Add-Computer -DomainName $domain -Credential ($cred_dom) -Force
        Restart-Computer
        }-argumentList `
        $element.Domain
          
    }
}

