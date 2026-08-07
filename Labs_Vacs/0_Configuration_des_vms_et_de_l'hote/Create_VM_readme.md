# Create_VM.csv — Documentation des colonnes

Ce fichier CSV est lu par `0_1_LABSP_Create.ps1` pour créer automatiquement des VM Hyper-V. Chaque ligne = une VM.

## Colonnes

| Colonne | Type | Obligatoire | Description |
|---|---|---|---|
| `VMName` | texte | oui | Nom de la VM (utilisé aussi comme nom du dossier et des fichiers VHDX). |
| `Gen` | entier | oui | Génération de la VM Hyper-V. `1` ou `2`. `2` requis pour Secure Boot/TPM (mode `IsoWin11`). |
| `RAM` | entier | oui | Mémoire de démarrage en **Go** (converti en octets dans le script, ex. `8` → 8 Go). |
| `CPU` | entier | oui | Nombre de processeurs virtuels. |
| `Switch` | texte | oui | Nom du/des switch(s) virtuel(s). Un seul switch : `WAN`. Deux switchs (2 cartes réseau) : `WAN;Lan` (séparés par `;`). Créé automatiquement s'il n'existe pas encore. |
| `SizeMain` | entier | oui | Taille du disque principal en **Go**. Utilisé seulement pour les modes `Null`, `IsoWin11`, `IsoWinServ2025` (disque dynamique vierge). Ignoré pour `SysprepWS2025` (disque différencié, hérite de la taille du parent). |
| `SizeSecond` | entier | oui (colonne conservée) | Taille d'un éventuel second disque, en Go. **Non utilisée actuellement** dans le script (aucun 2e disque n'est créé) — réservée pour une évolution future. |
| `OS` | texte | oui | Mode d'installation de l'OS. Voir valeurs possibles ci-dessous. |

## Valeurs possibles pour `OS`

| Valeur | Comportement |
|---|---|
| `Null` (ou vide) | Disque dynamique vierge créé, **aucun OS installé**. Aucun lecteur DVD ajouté. |
| `IsoWin11` | Disque dynamique vierge + lecteur DVD monté sur l'ISO Windows 11 (`$IsoWin11Path`). Active Secure Boot, TPM virtuel et clé de protection locale (nécessite `Gen = 2`). Boot configuré sur le DVD. |
| `IsoWinServ2025` | Disque dynamique vierge + lecteur DVD monté sur l'ISO Windows Server 2025 (`$IsoWinServ2025Path`). Boot configuré sur le DVD. |
| `SysprepWS2025` | Disque **différencié** basé sur le VHDX parent syspreppé (`$SysprepWS2025Path`). Pas de lecteur DVD — l'OS est déjà présent sur le disque parent. |

> Les chemins des ISO et du VHDX parent (`$IsoWin11Path`, `$IsoWinServ2025Path`, `$SysprepWS2025Path`) sont définis en haut du script `0_1_LABSP_Create.ps1` et à adapter selon l'environnement.

## Comportement général du script

- Si une VM du même nom existe déjà (`Get-VM`), elle est **ignorée** (pas de recréation).
- Le dossier de la VM est créé sous `$VmRootPath` (`D:\Lab_Vacs\<VMName>` par défaut).
- Les switches virtuels référencés dans `Switch` sont créés automatiquement (type `Private`) s'ils n'existent pas.
- La VM est démarrée automatiquement à la fin, et `vmconnect.exe` s'ouvre dessus.

## Exemple

```csv
VMName,Gen,RAM,CPU,Switch,SizeMain,SizeSecond,OS
SRV-MDT,2,8,2,WAN,127,100,IsoWinServ2025
Client,2,8,2,WAN,127,100,IsoWin11
ClientW11,2,8,2,WAN;Lan,127,100,SysprepWS2025
```