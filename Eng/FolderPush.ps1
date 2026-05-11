# ==============================
# Local Push: Work -> Public
# ==============================

$source = "C:\Users\Aymeric\Documents\MonProjetTravail"
$destination = "C:\Users\Aymeric\Documents\MonProjetPublic"

# ==============================
# Files to exclude
# ==============================

# Automatically exclude the currently running script
$currentScriptPath = $MyInvocation.MyCommand.Path

# Exclusions by name or pattern
# Examples: FolderPush.ps1, FolderPush-test.ps1, Push-dossier-A-vers-dossier-B.ps1, etc.
$excludedFilePatterns = @(
    "FolderPush*.ps1",
    "Push-dossier-*.ps1"
)

Write-Host ""
Write-Host "Source      : $source"
Write-Host "Destination : $destination"
Write-Host ""

# Check source folder
if (!(Test-Path $source)) {
    Write-Host "ERROR: The source folder does not exist."
    exit
}

# Create destination folder if it does not exist
if (!(Test-Path $destination)) {
    Write-Host "The destination folder does not exist. Creating it..."
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
}

Write-Host "Previewing differences..."
Write-Host ""

# Full preview without applying changes
robocopy $source $destination /MIR /L /XF $excludedFilePatterns

Write-Host ""
Write-Host "What do you want to do?"
Write-Host ""
Write-Host "1 - Copy new files only"
Write-Host "2 - Copy new files and overwrite modified files"
Write-Host "3 - Delete extra files from the public folder only"
Write-Host "4 - Full synchronization: copy + overwrite + delete"
Write-Host "5 - Cancel"
Write-Host "6 - Interactive mode: choose file by file"
Write-Host ""

$choice = Read-Host "Your choice"

Write-Host ""

switch ($choice) {

    "1" {
        Write-Host "Copying new files only..."
        Write-Host ""

        robocopy $source $destination /E /XC /XN /XO /XF $excludedFilePatterns

        Write-Host ""
        Write-Host "New files copied."
    }

    "2" {
        Write-Host "Copying new files and overwriting modified files..."
        Write-Host ""

        robocopy $source $destination /E /XF $excludedFilePatterns

        Write-Host ""
        Write-Host "Copy and overwrite completed."
    }

    "3" {
        Write-Host "Deleting extra files from the public folder..."
        Write-Host ""

        $confirmation = Read-Host "Warning: files missing from the source will be deleted from the public folder. Confirm? (y/n)"

        if ($confirmation -eq "y") {
            Write-Host ""
            Write-Host "Previewing deletions..."
            Write-Host ""

            robocopy $source $destination /E /PURGE /L /XF $excludedFilePatterns

            Write-Host ""
            $confirmation2 = Read-Host "Apply these deletions? (y/n)"

            if ($confirmation2 -eq "y") {
                Write-Host ""
                Write-Host "Applying deletions..."
                Write-Host ""

                robocopy $source $destination /E /PURGE /XC /XN /XO /XF $excludedFilePatterns

                Write-Host ""
                Write-Host "Deletion completed."
            }
            else {
                Write-Host "Deletion cancelled."
            }
        }
        else {
            Write-Host "Deletion cancelled."
        }
    }

    "4" {
        Write-Host "Full synchronization..."
        Write-Host ""

        $confirmation = Read-Host "Warning: the public folder will become identical to the work folder. Confirm? (y/n)"

        if ($confirmation -eq "y") {
            Write-Host ""
            Write-Host "Applying full synchronization..."
            Write-Host ""

            robocopy $source $destination /MIR /XF $excludedFilePatterns

            Write-Host ""
            Write-Host "Full synchronization completed."
        }
        else {
            Write-Host "Synchronization cancelled."
        }
    }

    "5" {
        Write-Host "No changes applied."
    }

    "6" {
        Write-Host "Interactive mode: choose file by file"
        Write-Host ""

        # Get source and destination files
        $sourceFiles = Get-ChildItem -Path $source -Recurse -File
        $destinationFiles = Get-ChildItem -Path $destination -Recurse -File

        # Filter excluded files from source
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

        # Convert source files to relative paths
        $sourceRelativeFiles = @{}

        foreach ($file in $sourceFiles) {
            $relativePath = $file.FullName.Substring($source.Length).TrimStart('\')
            $sourceRelativeFiles[$relativePath] = $file
        }

        # Convert destination files to relative paths
        $destinationRelativeFiles = @{}

        foreach ($file in $destinationFiles) {
            $relativePath = $file.FullName.Substring($destination.Length).TrimStart('\')
            $destinationRelativeFiles[$relativePath] = $file
        }

        # Full list of known relative paths
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
            # Case 1: new file
            # Present in Work, missing from Public
            # ==============================
            if ($sourceExists -and !$destinationExists) {
                Write-Host ""
                Write-Host "[NEW] $relativePath"
                Write-Host ""
                Write-Host "Work version:"
                Write-Host "  Date : $($sourceFile.LastWriteTime)"
                Write-Host "  Size : $($sourceFile.Length) bytes"
                Write-Host ""

                $answer = Read-Host "Copy this file to the public folder? (y/n)"

                if ($answer -eq "y") {
                    $targetPath = Join-Path $destination $relativePath
                    $targetDir = Split-Path $targetPath -Parent

                    if (!(Test-Path $targetDir)) {
                        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    }

                    Copy-Item -Path $sourceFile.FullName -Destination $targetPath -Force
                    Write-Host "Copied."
                }
                else {
                    Write-Host "Skipped."
                }
            }

            # ==============================
            # Case 2: deleted file
            # Missing from Work, present in Public
            # ==============================
            elseif (!$sourceExists -and $destinationExists) {
                Write-Host ""
                Write-Host "[DELETED FROM SOURCE / PRESENT IN PUBLIC] $relativePath"
                Write-Host ""
                Write-Host "Public version:"
                Write-Host "  Date : $($destinationFile.LastWriteTime)"
                Write-Host "  Size : $($destinationFile.Length) bytes"
                Write-Host ""

                $answer = Read-Host "Delete this file from the public folder? (y/n)"

                if ($answer -eq "y") {
                    Remove-Item -Path $destinationFile.FullName -Force
                    Write-Host "Deleted from public folder."
                }
                else {
                    Write-Host "Kept in public folder."
                }
            }

            # ==============================
            # Case 3: file exists on both sides
            # Modified if size OR date is different
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
                    Write-Host "[MODIFIED] $relativePath"
                    Write-Host ""

                    Write-Host "Work version:"
                    Write-Host "  Date : $($sourceFile.LastWriteTime)"
                    Write-Host "  Size : $($sourceFile.Length) bytes"
                    Write-Host ""

                    Write-Host "Public version:"
                    Write-Host "  Date : $($destinationFile.LastWriteTime)"
                    Write-Host "  Size : $($destinationFile.Length) bytes"
                    Write-Host ""

                    $answer = Read-Host "Overwrite the public file with the work version? (y/n)"

                    if ($answer -eq "y") {
                        Copy-Item -Path $sourceFile.FullName -Destination $destinationFile.FullName -Force
                        Write-Host "Overwritten."
                    }
                    else {
                        Write-Host "Kept."
                    }
                }
            }
        }

        Write-Host ""
        Write-Host "Interactive mode completed."
    }

    default {
        Write-Host "Invalid choice. No changes applied."
    }
}
