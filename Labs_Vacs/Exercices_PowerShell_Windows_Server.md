# Exercices PowerShell — Administration Windows Server

Ces exercices sont classés par niveau de difficulté croissant pour chaque thème. Ils supposent un serveur Windows Server (2019/2022) avec les rôles correspondants installés, dans un environnement de labo (VM/Hyper-V ou VMware recommandé).

---

## 1. Utilisateurs, Groupes, Partage de fichiers (Active Directory)

**Prérequis** : module `ActiveDirectory` (RSAT ou installé sur le DC), serveur promu en contrôleur de domaine.

1. Créer une unité d'organisation `OU=Personnel` avec deux sous-OU `Direction` et `Techniciens` via `New-ADOrganizationalUnit`.
2. Créer 5 utilisateurs (à partir d'un tableau ou d'un CSV) avec `New-ADUser`, en forçant le changement de mot de passe à la première connexion.
3. Créer les groupes de sécurité `GG_Direction` et `GG_Techniciens`, puis y ajouter les utilisateurs correspondants avec `Add-ADGroupMember`.
4. Écrire un script qui importe un CSV (`Nom;Prenom;Service`) et crée automatiquement les comptes + les ajoute au bon groupe selon le service.
5. Créer un partage de fichiers `\\SERVEUR\Commun` avec `New-SmbShare`, puis restreindre l'accès en lecture/écriture au groupe `GG_Direction` uniquement via `Grant-SmbShareAccess`.
6. Mettre en place un dossier par service avec des permissions NTFS héritées différentes (`Get-Acl` / `Set-Acl`), en s'assurant que les techniciens n'ont pas accès au dossier `Direction`.
7. Écrire un script d'audit qui liste tous les comptes désactivés (`Get-ADUser -Filter {Enabled -eq $false}`) et les membres de chaque groupe de sécurité.
8. Automatiser la désactivation des comptes des utilisateurs n'ayant pas ouvert de session depuis plus de 90 jours (`LastLogonDate`).

---

## 2. DNS

**Prérequis** : rôle DNS installé (`Install-WindowsFeature DNS`), module `DnsServer`.

1. Créer une nouvelle zone principale intégrée à AD `entreprise.local` avec `Add-DnsServerPrimaryZone`.
2. Ajouter des enregistrements A pour 3 serveurs fictifs (`Add-DnsServerResourceRecordA`).
3. Ajouter un enregistrement CNAME (alias) pointant vers l'un des serveurs créés.
4. Créer une zone de recherche inversée et vérifier la résolution avec `Resolve-DnsName`.
5. Ajouter un enregistrement MX pointant vers un futur serveur Exchange.
6. Écrire un script qui vérifie, pour une liste de noms de machines, si l'enregistrement DNS existe déjà avant de le créer (évite les doublons).
7. Configurer et tester le nettoyage automatique des enregistrements obsolètes (scavenging) avec `Set-DnsServerScavenging`.
8. Exporter la liste complète des enregistrements d'une zone dans un CSV avec `Get-DnsServerResourceRecord`.

---

## 3. WDS (Windows Deployment Services)

**Prérequis** : rôle WDS installé, DHCP et AD DS fonctionnels sur le réseau.

1. Installer le rôle WDS via PowerShell (`Install-WindowsFeature WDS -IncludeManagementTools`) et l'initialiser avec `wdsutil` ou le module `WDS`.
2. Ajouter une image de démarrage (boot.wim) et une image d'installation (install.wim) à partir d'un ISO Windows monté avec `Mount-DiskImage`.
3. Écrire un script qui automatise le montage de l'ISO, la copie des fichiers `boot.wim`/`install.wim`, puis leur import dans WDS.
4. Lister les images disponibles sur le serveur WDS et afficher leur taille/architecture.
5. Créer un filtre de préapprobation pour n'autoriser que certaines adresses MAC à démarrer en PXE.
6. Configurer les réponses PXE (répondre à tous / répondre uniquement aux clients connus) via les paramètres du service WDS.
7. Documenter (script + captures) le déploiement complet d'un poste client via PXE jusqu'à l'écran de sélection d'image.

---

## 4. MDT (Microsoft Deployment Toolkit)

**Prérequis** : MDT et ADK installés, partage de déploiement créé.

> MDT ne s'administre pas nativement par un module PowerShell Microsoft officiel complet ; on utilise surtout le module fourni par l'outil (`MicrosoftDeploymentToolkit`) une fois le partage créé via la console, puis on scripte dessus.

1. Créer un nouveau partage de déploiement (Deployment Share) et l'ajouter comme lecteur PowerShell avec `New-PSDrive -PSProvider MDTProvider`.
2. Importer un système d'exploitation (dossier ou ISO) dans le partage via `Import-MDTOperatingSystem`.
3. Créer une séquence de tâches (Task Sequence) standard de type "Standard Client Task Sequence" avec `Import-MDTTaskSequence`.
4. Ajouter une application (ex. 7-Zip, Notepad++) au partage de déploiement avec `Import-MDTApplication`, puis l'intégrer à la séquence de tâches.
5. Modifier le fichier `CustomSettings.ini` pour automatiser certaines réponses (nom d'ordinateur, jonction au domaine, fuseau horaire) et limiter les interactions à l'écran de déploiement.
6. Régénérer les images de démarrage (`Update-MDTDeploymentShare`) et vérifier qu'elles sont bien republiées vers WDS.
7. Simuler/documenter un déploiement complet d'un poste avec injection automatique d'un pilote spécifique (dossier `Out-of-Box Drivers`).

---

## 5. RDS (Remote Desktop Services)

**Prérequis** : module `RemoteDesktop`, un déploiement RDS de base (Session Host + Connection Broker) idéalement.

1. Installer les rôles nécessaires à un déploiement RDS "session-based" simple avec `Install-WindowsFeature` (RDS-RD-Server, RDS-Connection-Broker, RDS-Web-Access) ou via `New-RDSessionDeployment`.
2. Créer une collection de sessions (Session Collection) avec `New-RDSessionCollection`.
3. Publier une application distante (RemoteApp), par exemple Bloc-notes ou Calculatrice, avec `New-RDRemoteApp`.
4. Ajouter/retirer un utilisateur ou groupe de l'accès à une collection avec `Set-RDSessionCollectionConfiguration` ou en gérant les groupes autorisés.
5. Lister les sessions actives sur un serveur RDS avec `Get-RDUserSession`, puis écrire un script qui déconnecte automatiquement les sessions inactives depuis plus de X minutes.
6. Configurer des limites de session (temps maximal de connexion, déconnexion automatique) avec `Set-RDSessionCollectionConfiguration -MaxIdleTime` / `-MaxDisconnectionTime`.
7. Générer un rapport listant, pour chaque utilisateur connecté, la collection utilisée, l'heure de connexion et l'état de la session.
8. Mettre en place et tester une licence RDS (mode par utilisateur ou par périphérique) avec `Set-RDLicenseConfiguration`.

---

## 6. Exchange Server

**Prérequis** : Exchange Management Shell (EMS), un serveur Exchange installé (ou Exchange Online pour certains exercices équivalents avec le module `ExchangeOnlineManagement`).

1. Créer une nouvelle boîte aux lettres pour un utilisateur AD existant avec `Enable-Mailbox` (ou `New-Mailbox` si le compte n'existe pas encore).
2. Créer un groupe de distribution avec `New-DistributionGroup` et y ajouter des membres via `Add-DistributionGroupMember`.
3. Définir un quota de boîte aux lettres (avertissement, envoi bloqué, envoi/réception bloqués) avec `Set-Mailbox -IssueWarningQuota ...`.
4. Créer une règle de transport bloquant l'envoi de pièces jointes de plus de 10 Mo vers l'extérieur avec `New-TransportRule`.
5. Configurer une redirection automatique/transfert d'un utilisateur vers une autre boîte avec `Set-Mailbox -ForwardingAddress`.
6. Écrire un script qui liste toutes les boîtes aux lettres dépassant 80% de leur quota (`Get-MailboxStatistics`).
7. Créer une boîte aux lettres partagée (Shared Mailbox) pour un service, et donner les permissions "Envoyer en tant que" et "Accès total" à plusieurs utilisateurs (`Add-MailboxPermission`, `Add-RecipientPermission`).
8. Mettre en place une réponse d'absence automatique pour un utilisateur via `Set-MailboxAutoReplyConfiguration`.

---

## 7. SharePoint Server

**Prérequis** : module `SharePointServer` (SharePoint Management Shell) sur un serveur SharePoint on-premises, ou `PnP.PowerShell` pour SharePoint Online.

1. Créer une nouvelle collection de sites avec `New-SPSite` en définissant un modèle (équipe, communication...).
2. Créer une bibliothèque de documents et une liste personnalisée via PowerShell (`New-SPWeb` puis `$web.Lists.Add(...)`, ou `PnP.PowerShell` avec `New-PnPList`).
3. Ajouter des utilisateurs/groupes AD à un groupe SharePoint (ex. "Membres du site") avec `Add-SPUser` ou `Add-PnPUserToGroup`.
4. Définir des permissions différenciées (lecture seule / contribution) sur deux bibliothèques distinctes d'un même site.
5. Écrire un script qui liste toutes les collections de sites d'une batterie SharePoint avec leur taille de quota utilisée (`Get-SPSite`, `.Usage`).
6. Activer une fonctionnalité (feature) sur un site, par exemple la corbeille ou le versionnement de documents, avec `Enable-SPFeature`.
7. Automatiser une sauvegarde d'une collection de sites avec `Backup-SPSite`, puis tester la restauration avec `Restore-SPSite`.
8. (Bonus SPO) Réaliser les mêmes opérations de base (création de site, ajout d'utilisateurs, permissions) avec le module `PnP.PowerShell` sur un tenant SharePoint Online.

---

### Conseils généraux
- Toujours travailler dans un environnement de labo isolé (snapshots avant chaque manipulation risquée).
- Documenter chaque script avec des commentaires et des `Write-Host`/`Write-Output` explicites pour en garder une trace.
- Pour chaque thème, essayer d'écrire un script "tout-en-un" qui enchaîne plusieurs exercices (ex. création utilisateur AD → boîte Exchange → accès SharePoint) pour simuler un onboarding complet.
