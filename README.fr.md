# FolderPush

[English](README.md) | [Français](README.fr.md)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Plateforme](https://img.shields.io/badge/plateforme-Windows-0078D4?logo=windows)
![Licence](https://img.shields.io/badge/licence-MIT-green)

**FolderPush** est un script PowerShell de comparaison et de synchronisation contrôlée entre deux dossiers.

Il conserve un **dossier source** comme référence et met à jour un **dossier cible**, tout en permettant de contrôler les copies, les remplacements, les sauvegardes et les retraits de fichiers.

```text
Dossier source  ───────────────►  Dossier cible
   référence          synchronisation unidirectionnelle
```

FolderPush ne remplace pas Git et ne fournit pas d’historique de versions. Il constitue un outil simple et lisible pour synchroniser localement deux emplacements.

## Fonctionnalités

- comparaison récursive des dossiers source et cible ;
- détection des fichiers identiques, différents, nouveaux ou absents de la source ;
- copie des nouveaux fichiers ;
- remplacement des fichiers différents dans la cible ;
- synchronisation complète unidirectionnelle ;
- traitement interactif fichier par fichier ;
- sauvegarde des fichiers retirés de la cible au lieu d’une suppression définitive ;
- configuration externe dans un fichier texte ;
- exclusions par nom, motif, dossier ou extension ;
- résumé global et résumé par dossier ;
- affichage détaillé des différences ;
- export des résultats au format CSV ;
- vérification stricte du contenu par hash SHA-256 ;
- création automatique de journaux d’exécution ;
- création automatique du dossier cible lorsqu’il n’existe pas.

## Principe de fonctionnement

Le dossier source est toujours considéré comme la référence.

| État affiché par le script | Signification |
|---|---|
| `Identical` | Le fichier est considéré comme identique dans les deux dossiers. |
| `Different` | Le fichier existe des deux côtés, mais diffère selon la méthode de comparaison choisie. |
| `New` | Le fichier existe dans la source, mais pas dans la cible. |
| `Removed` | Le fichier n’existe plus dans la source, mais reste présent dans la cible. |

> [!IMPORTANT]
> FolderPush réalise une synchronisation **source vers cible**. Une modification effectuée uniquement dans la cible peut être remplacée par la version de la source.

## Méthodes de comparaison

### Comparaison rapide

Les modes de synchronisation utilisent :

- le chemin relatif ;
- le nom du fichier ;
- la date de dernière modification arrondie à la minute ;
- la taille du fichier.

Cette méthode est rapide et limite les écarts de quelques secondes pouvant apparaître entre différents systèmes de fichiers.

### Vérification stricte SHA-256

Le mode `9` calcule les hashes SHA-256 afin de comparer le contenu réel des fichiers.

Cette méthode est plus fiable, mais elle peut être sensiblement plus lente sur des dossiers volumineux ou contenant de gros fichiers.

> [!CAUTION]
> Les actions de copie et de synchronisation utilisent actuellement la comparaison rapide. Le mode SHA-256 est un mode de contrôle sans modification. Pour des données critiques, lancez le mode `9` avant une synchronisation complète.

## Prérequis

- Windows 10 ou Windows 11 ;
- Windows PowerShell 5.1 ou PowerShell 7 ;
- accès en lecture au dossier source ;
- accès en écriture au dossier cible et au dossier contenant le script.

Aucune dépendance tierce ni installation de `robocopy` n’est nécessaire.

## Fichiers du dépôt

```text
FolderPush/
├── FolderPush.ps1
├── FolderPush_config.en.example.txt
├── FolderPush_config.fr.example.txt
├── README.md
├── README.fr.md
└── LICENSE
```

Lors de son exécution, le script recherche toujours :

```text
FolderPush_config.txt
```

Il faut donc copier ou renommer l’un des deux fichiers d’exemple avec ce nom exact.

Exemple français :

```powershell
Copy-Item .\FolderPush_config.fr.example.txt .\FolderPush_config.txt
```

Exemple anglais :

```powershell
Copy-Item .\FolderPush_config.en.example.txt .\FolderPush_config.txt
```

Lorsque la configuration est absente, FolderPush génère automatiquement un modèle en anglais puis s’arrête afin de vous laisser le compléter.

## Installation

Clonez le dépôt :

```powershell
git clone https://github.com/AyDtn/FolderPush.git
cd FolderPush
```

Créez la configuration utilisée par le programme :

```powershell
Copy-Item .\FolderPush_config.fr.example.txt .\FolderPush_config.txt
```

Modifiez ensuite les chemins source et cible dans `FolderPush_config.txt`.

## Configuration

Exemple :

```ini
[Paths]
Source=C:\Chemin\DossierSource
Destination=D:\Chemin\DossierCible

[IgnoreFileNamesOrPatterns]
FolderPush*.ps1
FolderPush*.txt
Thumbs*.db
FolderPush_*.csv

[IgnoreFolderNamesOrPatterns]
FolderPush
FolderPush_Logs
FolderPush_Backup
.git

[IgnoreExtensions]
.tmp
.bak
.old
```

### Section `[Paths]`

| Clé | Description |
|---|---|
| `Source` | Dossier de référence à analyser. |
| `Destination` | Dossier cible à mettre à jour depuis la source. |

Les chemins peuvent contenir des espaces et ne doivent pas être entourés de guillemets.

### Section `[IgnoreFileNamesOrPatterns]`

Liste des noms ou motifs PowerShell de fichiers à ignorer.

Exemples :

```ini
FolderPush*.ps1
Thumbs*.db
*.log
```

### Section `[IgnoreFolderNamesOrPatterns]`

Tout fichier placé dans un dossier correspondant à l’un des motifs est exclu de l’analyse.

Exemples :

```ini
.git
FolderPush_Logs
FolderPush_Backup
Temp*
```

### Section `[IgnoreExtensions]`

Liste des extensions à ignorer :

```ini
.tmp
.bak
.old
```

Le point initial est ajouté automatiquement lorsqu’il est omis.

> [!WARNING]
> Ne publiez pas votre véritable fichier `FolderPush_config.txt` lorsqu’il contient des chemins personnels, des noms d’utilisateur ou des emplacements réseau internes. Conservez uniquement les fichiers d’exemple dans le dépôt et ajoutez la configuration utilisée localement au `.gitignore`.

## Utilisation

Ouvrez PowerShell dans le dossier du projet puis exécutez :

```powershell
.\FolderPush.ps1
```

Si l’exécution des scripts est bloquée pour la session courante :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\FolderPush.ps1
```

Cette commande modifie la stratégie d’exécution uniquement pour la fenêtre PowerShell en cours.

## Modes disponibles

| Mode | Action |
|---:|---|
| `1` | Copier uniquement les nouveaux fichiers de la source vers la cible. |
| `2` | Copier les nouveaux fichiers et remplacer les fichiers différents dans la cible. |
| `3` | Sauvegarder puis retirer de la cible les fichiers absents de la source. |
| `4` | Effectuer une synchronisation complète : copie, remplacement, sauvegarde et retrait. |
| `5` | Annuler sans appliquer de modification. |
| `6` | Choisir l’action fichier par fichier. |
| `7` | Afficher le tableau des différences sans modifier les dossiers. |
| `8` | Exporter le tableau des différences au format CSV. |
| `9` | Effectuer une vérification stricte par hash SHA-256, avec affichage et/ou export CSV. |

FolderPush affiche un résumé et demande une confirmation avant les opérations globales d’écriture.

## Sauvegardes

Lorsqu’un fichier est présent dans la cible mais absent de la source, FolderPush ne le supprime pas définitivement.

Il est déplacé vers :

```text
FolderPush_Backup/
└── AAAAMMJJ_HHMMSS/
    └── chemin relatif du fichier
```

L’arborescence relative est conservée afin de faciliter une éventuelle restauration manuelle.

## Journaux

Un journal est créé à chaque lancement :

```text
FolderPush_Logs/
└── FolderPush_Log_AAAAMMJJ_HHMMSS.txt
```

Il enregistre notamment :

- le démarrage et la fin du script ;
- les chemins source et cible ;
- le mode sélectionné ;
- les fichiers copiés ;
- les fichiers sauvegardés puis retirés ;
- les exports CSV réalisés.

## Exports CSV

Le mode `8` génère :

```text
FolderPush_Differences_AAAAMMJJ_HHMMSS.csv
```

Le mode SHA-256 peut générer :

```text
FolderPush_Hash_SHA256_AAAAMMJJ_HHMMSS.csv
```

Les fichiers CSV utilisent le point-virgule comme séparateur.

## Précautions recommandées

Avant une synchronisation complète :

1. vérifiez soigneusement les chemins source et cible ;
2. consultez le résumé des différences ;
3. utilisez le mode `7` ou le mode `9` en cas de doute ;
4. assurez-vous que les dossiers source et cible ne sont ni identiques ni imbriqués l’un dans l’autre ;
5. vérifiez que l’espace disponible est suffisant pour les sauvegardes.

## Limites connues

FolderPush ne gère pas :

- l’historique de versions ;
- les branches ;
- la fusion de modifications concurrentes ;
- la synchronisation bidirectionnelle ;
- la synchronisation des dossiers vides ;
- la restauration automatique des sauvegardes ;
- la planification automatique des exécutions ;
- les conflits lorsque la source et la cible ont toutes deux été modifiées.

Utilisez Git lorsque vous avez besoin d’un versionnement, de branches, de fusions ou d’un historique complet de développement.

## `.gitignore` recommandé

```gitignore
FolderPush_config.txt
FolderPush_Logs/
FolderPush_Backup/
FolderPush_Differences_*.csv
FolderPush_Hash_SHA256_*.csv
```

## Licence

Ce projet est distribué sous licence MIT. Consultez le fichier [`LICENSE`](LICENSE) pour plus d’informations.
