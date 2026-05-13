# ==============================
# Push local : Travail -> Public
# ==============================

$source = "C:\Users\Aymeric\Documents\MonProjetTravail"
$destination = "C:\Users\Aymeric\Documents\MonProjetPublic"

# ==============================
# Fichiers a exclure
# ==============================

# Exclusion automatique du script en cours d'execution
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

# Verification du dossier source
if (!(Test-Path $source)) {
    Write-Host "ERREUR : Le dossier source n'existe pas."
    exit
}

# Creation du dossier destination s'il n'existe pas
if (!(Test-Path $destination)) {
    Write-Host "Le dossier destination n'existe pas. Creation..."
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
}

Write-Host "Simulation des differences..."
Write-Host ""

# Simulation complete sans modification reelle
robocopy $source $destination /MIR /L /XF $excludedFilePatterns

Write-Host ""
Write-Host "Que voulez-vous faire ?"
Write-Host ""
Write-Host "1 - Copier uniquement les nouveaux fichiers"
Write-Host "2 - Copier les nouveaux fichiers et ecraser les fichiers modifies"
Write-Host "3 - Supprimer uniquement les fichiers en trop dans le dossier public"
Write-Host "4 - Synchronisation complete : copie + ecrasement + suppression"
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
        Write-Host "Copie des nouveaux fichiers terminee."
    }

    "2" {
        Write-Host "Copie des nouveaux fichiers et ecrasement des fichiers modifies..."
        Write-Host ""

        robocopy $source $destination /E /XF $excludedFilePatterns

        Write-Host ""
        Write-Host "Copie et ecrasement termines."
    }

    "3" {
        Write-Host "Suppression des fichiers en trop dans le dossier public..."
        Write-Host ""

        $confirmation = Read-Host "Attention : les fichiers absents de la source seront supprimes du public. Confirmer ? (o/n)"

        if ($confirmation -eq "o") {
            Write-Host ""
            Write-Host "Simulation des suppressions..."
            Write-Host ""

            robocopy $source $destination /E /PURGE /L /XF $excludedFilePatterns

            Write-Host ""
            $confirmation2 = Read-Host "Appliquer reellement la suppression ? (o/n)"

            if ($confirmation2 -eq "o") {
                Write-Host ""
                Write-Host "Application des suppressions..."
                Write-Host ""

                robocopy $source $destination /E /PURGE /XC /XN /XO /XF $excludedFilePatterns

                Write-Host ""
                Write-Host "Suppression terminee."
            }
            else {
                Write-Host "Suppression annulee."
            }
        }
        else {
            Write-Host "Suppression annulee."
        }
    }

    "4" {
        Write-Host "Synchronisation complete..."
        Write-Host ""

        $confirmation = Read-Host "Attention : le dossier public deviendra identique au dossier de travail. Confirmer ? (o/n)"

        if ($confirmation -eq "o") {
            Write-Host ""
            Write-Host "Application de la synchronisation complete..."
            Write-Host ""

            robocopy $source $destination /MIR /XF $excludedFilePatterns

            Write-Host ""
            Write-Host "Synchronisation complete terminee."
        }
        else {
            Write-Host "Synchronisation annulee."
        }
    }

    "5" {
        Write-Host "Aucune modification appliquee."
    }

    "6" {
        Write-Host "Mode interactif : choix fichier par fichier"
        Write-Host ""

        # Recuperation des fichiers source et destination
        $sourceFiles = Get-ChildItem -Path $source -Recurse -File
        $destinationFiles = Get-ChildItem -Path $destination -Recurse -File

        # Filtrage des fichiers exclus cote source
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

        # Liste complete des chemins relatifs connus
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
            # Present dans Travail, absent de Public
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
                    Write-Host "Copie."
                }
                else {
                    Write-Host "Ignore."
                }
            }

            # ==============================
            # Cas 2 : fichier supprime
            # Absent de Travail, present dans Public
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
                    Write-Host "Supprime du public."
                }
                else {
                    Write-Host "Conserve dans le public."
                }
            }

            # ==============================
            # Cas 3 : fichier existant des deux cotes
            # Modifie si taille differente OU date differente
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

                    $reponse = Read-Host "Ecraser le fichier public avec la version de travail ? (o/n)"

                    if ($reponse -eq "o") {
                        Copy-Item -Path $sourceFile.FullName -Destination $destinationFile.FullName -Force
                        Write-Host "ecrase."
                    }
                    else {
                        Write-Host "Conserve."
                    }
                }
            }
        }

        Write-Host ""
        Write-Host "Mode interactif termine."
    }

    default {
        Write-Host "Choix invalide. Aucune modification appliquee."
    }
}
