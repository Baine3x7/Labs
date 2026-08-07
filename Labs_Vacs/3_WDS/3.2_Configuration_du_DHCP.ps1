# Installation du service DHCP sur Windows Server
# Ce script installe le rôle DHCP sur un serveur Windows Server et configure les paramètres de base
Add-WindowsFeature -Name DHCP -IncludeManagementTools

# Configurer le service DHCP pour démarrer automatiquement
Set-Service -Name DHCPServer -StartupType Automatic

# Démarrer le service DHCP
Start-Service -Name DHCPServer

# Configurer une étendue DHCP
$ScopeName = "DHCP_Scope"
$StartRange = "192.168.100.100"
$EndRange = "192.168.100.200"
$SubnetMask = "255.255.255.0"
Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask
Set-DhcpServerv4Scope -ScopeId 192.168.100.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.100.0 -DnsServer 192.168.100.2 -DnsDomain "home.lan"
