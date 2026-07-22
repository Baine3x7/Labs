# Résumé — GPO de mapping de lecteur réseau

## Contexte

Suite du partage `\\192.168.0.185\Workgroup` (voir `Partage_toubleshoot.md`) : il fallait mapper automatiquement ce partage en lecteur `W:` sur tous les PC du domaine, sans intervention manuelle sur chaque poste. Solution retenue : une **GPO** avec une préférence "Mapped Drives", gérée à distance depuis le PC main via RSAT.

**OU ciblée** : `OU_Users` (et non une OU de PC), car le mapping de lecteur est configuré sous **Configuration utilisateur**, qui s'applique aux comptes utilisateurs et non aux machines. L'utilisateur partagé `pbaine` se trouve dans cette même OU, donc la GPO s'applique automatiquement à sa session peu importe le PC utilisé.

---

## 1. Prérequis — RSAT

```powershell
Get-Module -ListAvailable GroupPolicy
```
Vérifie que le module GPO est disponible sur le PC main. Sinon :
```powershell
Get-WindowsCapability -Name RSAT.GroupPolicy* -Online | Add-WindowsCapability -Online
```

## 2. Identifier l'OU cible

```powershell
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName
```
→ confirmé : `OU=OU_Users,DC=home,DC=lan`

## 3. Créer la GPO

```powershell
New-GPO -Name "Mapping-Workgroup" -Comment "Mappe le lecteur W vers \\192.168.0.185\Workgroup"
```

## 4. Lier la GPO à `OU_Users`

```powershell
New-GPLink -Name "Mapping-Workgroup" -Target "OU=OU_Users,DC=home,DC=lan"
```

## 5. Vérifier le lien

```powershell
Get-GPInheritance -Target "OU=OU_Users,DC=home,DC=lan"
```
→ `Mapping-Workgroup` doit apparaître dans `GpoLinks`.

## 6. Configurer le mapping de lecteur (via l'éditeur GPO)

Pas de cmdlet native pour cette partie — passage obligé par l'interface graphique :

```powershell
gpmc.msc
```

Dans la console :
1. **Group Policy Objects** → clic droit sur `Mapping-Workgroup` → **Modifier**
2. **Configuration utilisateur** → **Préférences** → **Paramètres Windows** → **Mappages de lecteurs**
3. Clic droit → **Nouveau** → **Lecteur mappé**
4. Renseigner :
   - **Action** : Mettre à jour
   - **Emplacement** : `\\192.168.0.185\Workgroup`
   - **Lettre de lecteur** : `W`
   - Cocher **Reconnecter** (persistance après reboot)
5. Onglet **Commun** → cocher **Exécuter dans le contexte de sécurité de l'utilisateur connecté**

## 7. Restreindre l'application (optionnel)

```powershell
Set-GPPermission -Name "Mapping-Workgroup" -TargetName "Domain Users" -TargetType Group -PermissionLevel GpoApply
```

## 8. Tester sur un PC client

```powershell
gpupdate /force
gpresult /r
Get-PSDrive W
```

---

## Résultat

Fonctionnel : le lecteur `W:` se mappe automatiquement vers `\\192.168.0.185\Workgroup` pour tout utilisateur de `OU_Users` (dont `pbaine`), sur n'importe quel PC du domaine, sans configuration manuelle par poste.