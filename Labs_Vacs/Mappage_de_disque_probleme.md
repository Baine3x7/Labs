# Récap — Dépannage mapping de disque réseau (domaine HOME)

## Contexte
Le client Windows (`CLIENTW11`, domaine `HOME` / `home.lan`) ne détectait pas le disque réseau mappé normalement via GPO.

## Diagnostic

1. **RSOP sur SRV-AD** (`gpresult /r`) : test fait sur la mauvaise machine au départ — le DC n'est pas représentatif du client.
2. **RSOP sur CLIENTW11** : confirmé le vrai problème →
   - `USER SETTINGS > Applied Group Policy Objects : N/A`
   - Seule `Default Domain Policy` s'appliquait (héritée du domaine root)
3. **Vérification avec `Get-GPInheritance`** sur l'OU `OU_Users` :
   ```powershell
   Get-GPInheritance -Target "OU=OU_Users,DC=home,DC=lan"
   ```
   → `GpoLinks : {}` — **aucune GPO n'était liée à cette OU**, seule `Default Domain Policy` héritée.

4. **Cause racine #1** : la GPO `Mapping-Workgroup` existait bien (`Get-GPO -All`) mais n'avait jamais été liée à l'OU `OU_Users`.

## Correctif #1 — Lier la GPO

```powershell
New-GPLink -Name "Mapping-Workgroup" -Target "OU=OU_Users,DC=home,DC=lan"
```

Vérification :
```powershell
Get-GPInheritance -Target "OU=OU_Users,DC=home,DC=lan"
```

## Cause racine #2 — Ordre de démarrage des VMs

Après avoir lié la GPO, le disque restait invisible sur :
- l'hôte des VM
- la VM client W11
- SRV-AD lui-même

...mais était visible depuis une machine physique **hors domaine** (connexion SMB simple, sans dépendance à l'authentification de domaine, au DNS AD, ni aux GPO).

**Explication** : SRV-AD (DC + DNS du domaine) démarrait **après** les clients. Au boot, les machines du domaine n'arrivaient pas à :
- localiser le DC (Netlogon)
- résoudre le DNS interne du domaine (`_ldap._tcp.dc._msdcs.home.lan`, etc.)
- traiter les GPO au logon

→ Une machine physique hors domaine ne dépend que du port SMB (445) qui répondait déjà, donc n'était pas affectée.

## Correctif #2 — Ordre de démarrage + resynchro

1. Toujours démarrer **SRV-AD (le DC) en premier**, attendre qu'il soit pleinement opérationnel (services AD DS + DNS up).
2. Démarrer ensuite les VMs clientes.
3. Sur le client, si besoin de forcer une resynchro sans tout redémarrer :
   ```powershell
   ipconfig /flushdns
   nltest /dsgetdc:home.lan
   gpupdate /force
   ```

## Résultat
Redémarrage complet dans le bon ordre (DC avant clients) → problème résolu, disque réseau détecté normalement.

## À retenir pour le lab
- Toujours démarrer le DC en premier.
- `Get-GPInheritance` est l'outil le plus rapide pour vérifier si une GPO est bien liée à une OU.
- `gpresult /r` doit être exécuté sur la machine concernée, pas sur le DC.
- Une machine hors domaine ne reflète pas le comportement réseau/GPO d'une machine membre du domaine.

---

# Annexe — Mapping manuel d'un disque réseau (PowerShell / net use)

## Contexte
Besoin de mapper manuellement un disque vers `\\192.168.0.185\Workgroup` avec des identifiants spécifiques (compte de domaine `HOME\tbaine`).

## Tentative avec New-PSDrive

```powershell
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\192.168.0.185\Workgroup" -Persist -Credential (Get-Credential)
```

❌ Erreur : `-Persist` et `-Credential` ne sont **pas compatibles** ensemble sur `New-PSDrive` (PowerShell délègue `-Persist` à l'équivalent de `net use`, qui ne prend pas l'objet `Credential` de la même façon).

## Solution retenue — net use

```powershell
net use Z: \\192.168.0.185\Workgroup /user:HOME\tbaine 'Pa$$w0rd' /persistent:yes
```

Points clés :
- Format du compte : `DOMAINE\utilisateur` (`HOME\tbaine`), pas juste `tbaine`.
- Mot de passe entre **guillemets simples** si il contient des caractères spéciaux comme `$` (évite l'interprétation en variable PowerShell).
- Si une connexion existe déjà vers la même adresse avec d'autres identifiants, la supprimer avant de retester :
  ```powershell
  net use Z: /delete
  ```

## Problème rencontré — disque invisible dans l'Explorateur

Après un `net use` réussi (`Command completed successfully`), le disque était accessible en ligne de commande mais **absent de l'Explorateur Windows**.

**Cause** : la commande a été lancée depuis un terminal **élevé** (administrateur), alors que l'Explorateur tourne en session **standard**. Windows isole les lecteurs mappés entre ces deux contextes par sécurité.

**Correctif** :
1. Soit relancer `net use` depuis un terminal **non-élevé**.
2. Soit activer la clé de registre qui lie les deux sessions :
   ```powershell
   New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLinkedConnections" -Value 1 -PropertyType DWord -Force
   ```
   puis **redémarrer la session** (logoff/logon ou reboot) pour appliquer.

## Point PowerShell à noter — Restart-Computer

`Restart-Computer` utilise la syntaxe PowerShell (tiret), pas la syntaxe cmd (`/force`) :

```powershell
Restart-Computer -Force
```
(`Restart-Computer /force` échoue car `/force` est interprété comme un nom d'ordinateur cible.)

## À retenir
- `New-PSDrive -Persist` + `-Credential` = incompatibles → utiliser `net use` si des identifiants spécifiques sont nécessaires.
- Toujours utiliser `DOMAINE\utilisateur` pour un compte de domaine dans `/user:`.
- Un mapping fait depuis un terminal élevé n'apparaît pas automatiquement dans l'Explorateur (session standard) sans `EnableLinkedConnections`.
- `Restart-Computer -Force`, pas `/force`.