# FolderPush

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

[English version](README.md)

Script PowerShell permettant de synchroniser proprement un dossier de travail vers un dossier public.

L’objectif est simple : disposer d’un dossier de travail dans lequel les fichiers peuvent être modifiés librement, puis pousser une version propre vers un second dossier destiné à être publié, partagé ou utilisé comme version stable.

Ce script n’a pas pour objectif de remplacer Git. Il sert plutôt de couche de synchronisation locale entre deux dossiers, avec une logique proche d’un `push`, mais sans historique de version.

## Principe

Le script fonctionne avec deux dossiers :

```text
Dossier de travail  ->  Dossier public
```

Le dossier de travail est considéré comme la source principale.

Le dossier public est le dossier de destination. Il peut être mis à jour de plusieurs manières selon le besoin :

```text
copier les nouveaux fichiers
mettre à jour les fichiers modifiés
supprimer les fichiers qui n’existent plus dans la source
synchroniser complètement les deux dossiers
choisir les actions fichier par fichier
```

## Fonctionnalités

Le script permet notamment de :

```text
simuler les différences avant modification
copier uniquement les nouveaux fichiers
copier et écraser les fichiers modifiés
supprimer les fichiers en trop dans le dossier public
faire une synchronisation complète
choisir manuellement l’action à effectuer pour chaque fichier
ignorer automatiquement certains fichiers PowerShell
```

La simulation utilise `robocopy`, ce qui permet d’avoir une première vue rapide des différences entre les deux dossiers.

## Modes disponibles

Au lancement, le script propose plusieurs choix :

```text
1 - Copier uniquement les nouveaux fichiers
2 - Copier les nouveaux fichiers et écraser les fichiers modifiés
3 - Supprimer uniquement les fichiers en trop dans le dossier public
4 - Synchronisation complète : copie + écrasement + suppression
5 - Annuler
6 - Mode interactif : choisir fichier par fichier
```

## Mode interactif

Le mode interactif permet de traiter les fichiers un par un.

Il distingue trois cas principaux :

```text
[NOUVEAU]
Fichier présent dans le dossier de travail mais absent du dossier public.

[MODIFIE]
Fichier présent dans les deux dossiers, mais avec une taille ou une date différente.

[SUPPRIME DE LA SOURCE / PRESENT DANS PUBLIC]
Fichier absent du dossier de travail mais encore présent dans le dossier public.
```

Pour chaque fichier concerné, le script demande confirmation avant d’appliquer l’action.

Exemple :

```text
[MODIFIE] index.html

Version travail :
  Date  : 11/05/2026 01:34:12
  Taille: 15420 octets

Version publique :
  Date  : 10/05/2026 23:18:45
  Taille: 15420 octets

Écraser le fichier public avec la version de travail ? (o/n)
```

## Fichiers ignorés

Le script ignore automatiquement certains fichiers afin d’éviter de copier le script lui-même dans le dossier public.

Par défaut, les fichiers correspondant aux motifs suivants sont ignorés :

```powershell
FolderPush*.ps1
Push-dossier-*.ps1
```

Le script en cours d’exécution est également exclu automatiquement, même si son nom change.

Cette règle permet de garder le dossier public propre, sans y envoyer le fichier PowerShell utilisé pour faire la synchronisation.

## Configuration

Les deux chemins principaux sont définis au début du script :

```powershell
$source = "C:\Users\Aymeric\Documents\MonProjetTravail"
$destination = "C:\Users\Aymeric\Documents\MonProjetPublic"
```

Il suffit de modifier ces deux variables selon l’organisation voulue.

Exemple :

```powershell
$source = "C:\Users\Aymeric\Documents\Obsidian\VaultTravail"
$destination = "C:\Users\Aymeric\Documents\Public\VaultStable"
```

## Utilisation

Depuis PowerShell, se placer dans le dossier contenant le script :

```powershell
cd "C:\chemin\vers\le\script"
```

Puis lancer :

```powershell
.\FolderPush.ps1
```

Si l’exécution des scripts PowerShell est bloquée sur la machine, il peut être nécessaire d’autoriser temporairement l’exécution pour la session en cours :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Puis relancer le script.

## Comportement important

Le choix `4 - Synchronisation complète` utilise une logique de miroir.

Cela signifie que le dossier public devient identique au dossier de travail :

```text
les nouveaux fichiers sont copiés
les fichiers modifiés sont écrasés
les fichiers absents de la source sont supprimés du dossier public
```

Ce mode est pratique pour publier une version propre, mais il doit être utilisé après vérification de la simulation.

## Cas d’usage

Ce script peut être utile pour :

```text
maintenir un dossier public à partir d’un dossier de travail
publier une version stable d’un dossier Obsidian
séparer un espace brouillon d’un espace propre
préparer un dossier à envoyer, partager ou archiver
mettre à jour un dossier local sans passer par Git
```

## Limites

Ce script ne fournit pas :

```text
d’historique de version
de système de branches
de retour arrière automatique
de gestion de conflit avancée
```

Pour ces besoins, Git reste plus adapté.

Ce script est volontairement simple et local. Il sert surtout à éviter les copies manuelles entre dossiers tout en gardant un minimum de contrôle sur les fichiers copiés, modifiés ou supprimés.
