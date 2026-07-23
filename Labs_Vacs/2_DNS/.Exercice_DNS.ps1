# 1. Créer une nouvelle zone principale intégrée à AD home.lan avec Add-DnsServerPrimaryZone.
Add-DnsServerPrimaryZone -Name "home.lan" -ReplicationScope "Domain" -PassThru

# 2. Ajouter des enregistrements A pour 3 serveurs fictifs (Add-DnsServerResourceRecordA). (Sert à avoir des enregistrements DNS pour les tests de résolution de noms dans la zone home.lan)
Add-DnsServerResourceRecordA -Name "SRV-1" -ZoneName "home.lan" -IPv4Address "192.168.0.186"
Add-DnsServerResourceRecordA -Name "SRV-2" -ZoneName "home.lan" -IPv4Address "192.168.0.187"
Add-DnsServerResourceRecordA -Name "SRV-3" -ZoneName "home.lan" -IPv4Address "192.168.0.188"

# 3. Ajouter un enregistrement CNAME (alias) pointant vers l'un des serveurs créés.
Add-DnsServerResourceRecordCName -Name "SRV-1-Alias" -ZoneName "home.lan" -HostNameAlias "SRV-1.home.lan"

# 4. Créer une zone de recherche inversée et vérifier la résolution avec Resolve-DnsName.
Add-DnsServerPrimaryZone -NetworkId "192.168.0.0/24" -ReplicationScope "Domain" -PassThru
Resolve-DnsName -Name "SRV-1.home.lan" -Server "localhost"

# 5. Ajouter un enregistrement MX pointant vers un futur serveur Exchange.
Add-DnsServerResourceRecordMX -Name "mail" -ZoneName "home.lan" -MailExchange "SRV-1.home.lan" -Preference 10

# 6. Écrire un script qui vérifie, pour une liste de noms de machines, si l'enregistrement DNS existe déjà avant de le créer (évite les doublons).
powershell.exe -ExecutionPolicy bypass .\2.6_Verification.ps1 -ZoneName "home.lan" -CsvPath ".\Verification_DNS.csv"

# 7. Configurer et tester le nettoyage automatique des enregistrements obsolètes (scavenging) avec Set-DnsServerScavenging.
Set-DnsServerScavenging -ScavengingState $true -RefreshInterval 7.00:00:00 -NoRefreshInterval 7.00:00:00

# 8.1 Exporter la liste complète des enregistrements d'une zone dans un texte avec Get-DnsServerResourceRecord.
Get-DnsServerResourceRecord -ZoneName "home.lan" | Select-Object HostName, RecordType, RecordData | Out-File -FilePath ".\rapport_DNS_Records.txt"

# 8.2 Exporter la liste complète des enregistrements d'une zone dans un CSV avec Get-DnsServerResourceRecord.
Get-DnsServerResourceRecord -ZoneName "home.lan" | Select-Object HostName, RecordType, RecordData | Export-Csv -Path ".\rapport_DNS_Records.csv" -NoTypeInformation

