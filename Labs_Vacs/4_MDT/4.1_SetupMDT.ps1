<# 1. Créer un nouveau partage de déploiement (Deployment Share) et l'ajouter comme lecteur PowerShell avec `New-PSDrive -PSProvider MDTProvider`.
2. Importer un système d'exploitation (dossier ou ISO) dans le partage via `Import-MDTOperatingSystem`.
3. Créer une séquence de tâches (Task Sequence) standard de type "Standard Client Task Sequence" avec `Import-MDTTaskSequence`.
4. Ajouter une application (ex. 7-Zip, Notepad++) au partage de déploiement avec `Import-MDTApplication`, puis l'intégrer à la séquence de tâches.
5. Modifier le fichier `CustomSettings.ini` pour automatiser certaines réponses (nom d'ordinateur, jonction au domaine, fuseau horaire) et limiter les interactions à l'écran de déploiement.
6. Régénérer les images de démarrage (`Update-MDTDeploymentShare`) et vérifier qu'elles sont bien republiées vers WDS.
7. Simuler/documenter un déploiement complet d'un poste avec injection automatique d'un pilote spécifique (dossier `Out-of-Box Drivers`). #>

# 1. Créer un nouveau partage de déploiement (Deployment Share) et l'ajouter comme lecteur PowerShell avec `New-PSDrive -PSProvider MDTProvider`.

