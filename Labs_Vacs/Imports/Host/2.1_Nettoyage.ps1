$ousToDelete = @(
    "OU=Utilisateurs,DC=home,DC=lan",
    "OU=fds,DC=home,DC=lan",
    "OU=Groupes,DC=home,DC=lan",
    "OU=Groups,DC=home,DC=lan",
    "OU=OU_Users,DC=home,DC=lan",
    "OU=OU_Groups,DC=home,DC=lan"
)

foreach ($ou in $ousToDelete) {
    # Retire la protection sur l'OU elle-même et sur tout son contenu
    Get-ADObject -Filter * -SearchBase $ou -SearchScope Subtree -Properties ProtectedFromAccidentalDeletion |
        Where-Object { $_.ProtectedFromAccidentalDeletion -eq $true } |
        Set-ADObject -ProtectedFromAccidentalDeletion $false

    Remove-ADOrganizationalUnit -Identity $ou -Recursive -Confirm:$false
    Write-Host "$ou supprimée avec son contenu" -ForegroundColor Green
}