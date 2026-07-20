$acl = Get-Acl "D:\Partage\Dir"
$acl.SetAccessRuleProtection($true, $false)   # $true = protéger (couper l'héritage), $false = ne pas garder les règles héritées existantes

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "GS_Dir", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($rule)

Set-Acl "D:\Partage\Dir" $acl