# ==============================
# Push local : Travail -> Public
# ==============================

$source = "C:\Users\Aymeric\Documents\MonProjetTravail"
$destination = "C:\Users\Aymeric\Documents\MonProjetPublic"

# ==============================
# Fichiers à exclure
# ==============================

# Exclusion automatique du script en cours d'exécution
$currentScriptPath = $MyInvocation.MyCommand.Path

# Exclusions par nom ou motif
# Exemple : Push-dossier-A-vers-dossier-B.ps1, Push-dossier-test.ps1, etc.
$excludedFilePatterns = @(
    "FolderPush*.ps1",
    "Push-dossier-*.ps1"
)

Write-Host ""
Write-Host "Source      : $source"
Write-Host "Destination : $destination"
Write-Host ""

# Vérification du dossier source
if (!(Test-Path $source)) {
    Write-Host "ERREUR : Le dossier source n'existe pas."
    exit
}

# Création du dossier destination s'il n'existe pas
if (!(Test-Path $destination)) {
    Write-Host "Le dossier destination n'existe pas. Création..."
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
}

Write-Host "Simulation des différences..."
Write-Host ""

# Simulation complète sans modification réelle
robocopy $source $destination /MIR /L /XF $excludedFilePatterns

Write-Host ""
Write-Host "Que voulez-vous faire ?"
Write-Host ""
Write-Host "1 - Copier uniquement les nouveaux fichiers"
Write-Host "2 - Copier les nouveaux fichiers et écraser les fichiers modifiés"
Write-Host "3 - Supprimer uniquement les fichiers en trop dans le dossier public"
Write-Host "4 - Synchronisation complète : copie + écrasement + suppression"
Write-Host "5 - Annuler"
Write-Host "6 - Mode interactif : choisir fichier par fichier"
Write-Host ""

$choix = Read-Host "Votre choix"

Write-Host ""

switch ($choix) {

    "1" {
        Write-Host "Copie uniquement des nouveaux fichiers..."
        Write-Host ""

        robocopy $source $destination /E /XC /XN /XO /XF $excludedFilePatterns

        Write-Host ""
        Write-Host "Copie des nouveaux fichiers terminée."
    }

    "2" {
        Write-Host "Copie des nouveaux fichiers et écrasement des fichiers modifiés..."
        Write-Host ""

        robocopy $source $destination /E /XF $excludedFilePatterns

        Write-Host ""
        Write-Host "Copie et écrasement terminés."
    }

    "3" {
        Write-Host "Suppression des fichiers en trop dans le dossier public..."
        Write-Host ""

        $confirmation = Read-Host "Attention : les fichiers absents de la source seront supprimés du public. Confirmer ? (o/n)"

        if ($confirmation -eq "o") {
            Write-Host ""
            Write-Host "Simulation des suppressions..."
            Write-Host ""

            robocopy $source $destination /E /PURGE /L /XF $excludedFilePatterns

            Write-Host ""
            $confirmation2 = Read-Host "Appliquer réellement la suppression ? (o/n)"

            if ($confirmation2 -eq "o") {
                Write-Host ""
                Write-Host "Application des suppressions..."
                Write-Host ""

                robocopy $source $destination /E /PURGE /XC /XN /XO /XF $excludedFilePatterns

                Write-Host ""
                Write-Host "Suppression terminée."
            }
            else {
                Write-Host "Suppression annulée."
            }
        }
        else {
            Write-Host "Suppression annulée."
        }
    }

    "4" {
        Write-Host "Synchronisation complète..."
        Write-Host ""

        $confirmation = Read-Host "Attention : le dossier public deviendra identique au dossier de travail. Confirmer ? (o/n)"

        if ($confirmation -eq "o") {
            Write-Host ""
            Write-Host "Application de la synchronisation complète..."
            Write-Host ""

            robocopy $source $destination /MIR /XF $excludedFilePatterns

            Write-Host ""
            Write-Host "Synchronisation complète terminée."
        }
        else {
            Write-Host "Synchronisation annulée."
        }
    }

    "5" {
        Write-Host "Aucune modification appliquée."
    }

    "6" {
        Write-Host "Mode interactif : choix fichier par fichier"
        Write-Host ""

        # Récupération des fichiers source et destination
        $sourceFiles = Get-ChildItem -Path $source -Recurse -File
        $destinationFiles = Get-ChildItem -Path $destination -Recurse -File

        # Filtrage des fichiers exclus côté source
        $sourceFiles = $sourceFiles | Where-Object {
            $file = $_

            $isCurrentScript = $false
            if ($currentScriptPath) {
                $isCurrentScript = ($file.FullName -eq $currentScriptPath)
            }

            $isExcludedByPattern = $false
            foreach ($pattern in $excludedFilePatterns) {
                if ($file.Name -like $pattern) {
                    $isExcludedByPattern = $true
                    break
                }
            }

            -not $isCurrentScript -and -not $isExcludedByPattern
        }

        # Conversion des fichiers source en chemins relatifs
        $sourceRelativeFiles = @{}

        foreach ($file in $sourceFiles) {
            $relativePath = $file.FullName.Substring($source.Length).TrimStart('\')
            $sourceRelativeFiles[$relativePath] = $file
        }

        # Conversion des fichiers destination en chemins relatifs
        $destinationRelativeFiles = @{}

        foreach ($file in $destinationFiles) {
            $relativePath = $file.FullName.Substring($destination.Length).TrimStart('\')
            $destinationRelativeFiles[$relativePath] = $file
        }

        # Liste complète des chemins relatifs connus
        $allRelativePaths = @($sourceRelativeFiles.Keys + $destinationRelativeFiles.Keys) | Sort-Object -Unique

        foreach ($relativePath in $allRelativePaths) {

            $sourceExists = $sourceRelativeFiles.ContainsKey($relativePath)
            $destinationExists = $destinationRelativeFiles.ContainsKey($relativePath)

            $sourceFile = $null
            $destinationFile = $null

            if ($sourceExists) {
                $sourceFile = $sourceRelativeFiles[$relativePath]
            }

            if ($destinationExists) {
                $destinationFile = $destinationRelativeFiles[$relativePath]
            }

            # ==============================
            # Cas 1 : fichier nouveau
            # Présent dans Travail, absent de Public
            # ==============================
            if ($sourceExists -and !$destinationExists) {
                Write-Host ""
                Write-Host "[NOUVEAU] $relativePath"
                Write-Host ""
                Write-Host "Version travail :"
                Write-Host "  Date  : $($sourceFile.LastWriteTime)"
                Write-Host "  Taille: $($sourceFile.Length) octets"
                Write-Host ""

                $reponse = Read-Host "Copier ce fichier vers le dossier public ? (o/n)"

                if ($reponse -eq "o") {
                    $targetPath = Join-Path $destination $relativePath
                    $targetDir = Split-Path $targetPath -Parent

                    if (!(Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }

                    Copy-Item -Path $sourceFile.FullName -Destination $targetPath -Force
                    Write-Host "Copié."
                }
                else {
                    Write-Host "Ignoré."
                }
            }

            # ==============================
            # Cas 2 : fichier supprimé
            # Absent de Travail, présent dans Public
            # ==============================
            elseif (!$sourceExists -and $destinationExists) {
                Write-Host ""
                Write-Host "[SUPPRIME DE LA SOURCE / PRESENT DANS PUBLIC] $relativePath"
                Write-Host ""
                Write-Host "Version publique :"
                Write-Host "  Date  : $($destinationFile.LastWriteTime)"
                Write-Host "  Taille: $($destinationFile.Length) octets"
                Write-Host ""

                $reponse = Read-Host "Supprimer ce fichier du dossier public ? (o/n)"

                if ($reponse -eq "o") {
                    Remove-Item -Path $destinationFile.FullName -Force
                    Write-Host "Supprimé du public."
                }
                else {
                    Write-Host "Conservé dans le public."
                }
            }

            # ==============================
            # Cas 3 : fichier existant des deux côtés
            # Modifié si taille différente OU date différente
            # ==============================
            elseif ($sourceExists -and $destinationExists) {

                $different = $false

                if ($sourceFile.Length -ne $destinationFile.Length) {
                    $different = $true
                }
                elseif ($sourceFile.LastWriteTime -ne $destinationFile.LastWriteTime) {
                    $different = $true
                }

                if ($different) {
                    Write-Host ""
                    Write-Host "[MODIFIE] $relativePath"
                    Write-Host ""

                    Write-Host "Version travail :"
                    Write-Host "  Date  : $($sourceFile.LastWriteTime)"
                    Write-Host "  Taille: $($sourceFile.Length) octets"
                    Write-Host ""

                    Write-Host "Version publique :"
                    Write-Host "  Date  : $($destinationFile.LastWriteTime)"
                    Write-Host "  Taille: $($destinationFile.Length) octets"
                    Write-Host ""

                    $reponse = Read-Host "Écraser le fichier public avec la version de travail ? (o/n)"

                    if ($reponse -eq "o") {
                        Copy-Item -Path $sourceFile.FullName -Destination $destinationFile.FullName -Force
                        Write-Host "Écrasé."
                    }
                    else {
                        Write-Host "Conservé."
                    }
                }
            }
        }

        Write-Host ""
        Write-Host "Mode interactif terminé."
    }

    default {
        Write-Host "Choix invalide. Aucune modification appliquée."
    }
}
