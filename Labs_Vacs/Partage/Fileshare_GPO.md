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
Ne doit rien retourner

## 2. Identifier l'OU cible

```powershell
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName
```
→ confirmé : `OU=OU_Users,DC=home,DC=lan`

## 3.Gestion de la GPO
### 3.1 Créer la GPO
```powershell
New-GPO -Name "Mapping-Workgroup" -Comment "Mappe le lecteur W vers \\192.168.0.185\Workgroup"
```
### 3.2 Supprimer la GPO
```powershell
Remove-GPO -Name "Mapping-Workgroup"
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

---

## 9. Dépannage — lecteur qui ne se mappe pas malgré une GPO bien liée

### Contexte du problème

Après un redémarrage client, `Get-PSDrive W` ne retournait rien alors que la GPO semblait correctement configurée. Or, entre-temps, la GPO avait été **renommée** (`Mapping-Workgroup` → `Mapping-Share`) et **reconfigurée** (lettre `W` → `V`, chemin `\Workgroup` → `\Share`) sans mise à jour de cette doc — d'où la confusion initiale.

### Démarche de diagnostic

1. **Vérifier que la GPO s'applique bien à la session utilisateur** (pas seulement liée à l'OU) :
   ```powershell
   gpresult /r
   ```
   → confirme la GPO appliquée sous "USER SETTINGS", sans filtrage.

2. **Vérifier le lien GPO ↔ OU** :
   ```powershell
   Get-GPInheritance -Target "OU=OU_Users,DC=home,DC=lan"
   ```
   → un seul lien attendu dans `GpoLinks`, pas de doublon ni de blocage d'héritage.

3. **Consulter les logs d'erreurs des préférences GPO** (Group Policy Preferences loggue les échecs) :
   ```powershell
   Get-EventLog -LogName Application -Source "Group Policy Drive Maps" -Newest 10
   ```
   → a révélé que la préférence réelle concernait le lecteur **`V:`**, pas `W:` comme documenté.

4. **Générer un rapport RSOP détaillé** pour voir la config exacte reçue par le client :
   ```powershell
   gpresult /h C:\rsop.html
   ```
   → a confirmé le chemin réseau réellement configuré : `\\192.168.0.185\Share` (et non `\Workgroup`).

5. **Vérifier l'existence et l'accessibilité du partage cible** :
   ```powershell
   Test-Path \\192.168.0.185\Share
   Test-Connection 192.168.0.185
   ```
   → le serveur répondait (ping OK) mais le partage `Share` n'existait pas.

6. **Lister les partages réels sur le serveur** (depuis `SRV-AD`) :
   ```powershell
   Get-SmbShare
   ```
   → ni `Workgroup` ni `Share` n'existaient ; un partage nommé `D` (pointant vers `D:\`) était en réalité le partage à utiliser.

### Cause racine

Décalage entre la documentation existante et la configuration réelle de la GPO/du partage (renommages successifs non documentés), combiné au fait qu'un mapping de lecteur en **préférence** GPO (Configuration utilisateur) ne se (re)applique de façon fiable qu'à un **logon complet** (déconnexion/reconnexion ou redémarrage), pas à un simple `gpupdate /force`.

### Résolution

Une fois le bon nom de lecteur (`V`) et le bon chemin réseau (`\\192.168.0.185\D` via le partage `D`) confirmés, et après un redémarrage complet du client avec ouverture de session, le mapping s'est fait normalement — vérifié à la fois sur le client et directement sur `SRV-AD`.

### À retenir pour la suite

- Toujours vérifier la config **actuelle** de la GPO (`gpmc.msc` → préférence → double-clic) plutôt que de se fier uniquement à une doc antérieure si le comportement ne correspond pas.
- `Get-EventLog -Source "Group Policy Drive Maps"` est le point d'entrée le plus rapide pour diagnostiquer un échec de mapping (indique la lettre et le nom de la GPO concernée).
- `gpresult /h fichier.html` donne le détail complet (lettre, chemin UNC, action, contexte de sécurité) tel que reçu par le client — utile pour repérer un écart entre la doc et la réalité.
- Un mapping de lecteur en préférence GPO nécessite un logon complet pour se réappliquer fiablement ; un `gpupdate /force` seul peut ne pas suffire.