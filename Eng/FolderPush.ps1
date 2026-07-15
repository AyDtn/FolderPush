# ==============================
# FolderPush - English version
# Controlled source -> destination folder comparison and synchronization
# ==============================

$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = (Get-Location).Path
}

$configPath = Join-Path $scriptDirectory "FolderPush_config.txt"
$currentScriptPath = $MyInvocation.MyCommand.Path
$script:logPath = $null

function Write-Log {
    param([string]$Message)

    if ($script:logPath) {
        Add-Content `
            -Path $script:logPath `
            -Value ("{0} - {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message) `
            -Encoding UTF8
    }
}

function Initialize-Log {
    param([string]$Root)

    $logDirectory = Join-Path $Root "FolderPush_Logs"

    if (!(Test-Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    $script:logPath = Join-Path $logDirectory (
        "FolderPush_Log_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    )

    Write-Log "Started"
}

function New-DefaultConfigFile {
    param([string]$Path)

    @'
# FolderPush_config.txt
# FolderPush configuration file.
# Lines beginning with # are ignored.
# Do not place quotation marks around paths.

[Paths]
Source=C:\Path\SourceFolder
Destination=D:\Path\DestinationFolder

[IgnoreFileNamesOrPatterns]
FolderPush*.ps1
FolderPush*.txt
Push-folder-*.ps1
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
'@ | Set-Content -Path $Path -Encoding UTF8
}

function Read-FolderPushConfig {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        New-DefaultConfigFile -Path $Path
        Write-Host "Configuration file not found. A template was created: $Path" -ForegroundColor Yellow
        exit
    }

    $config = [ordered]@{
        Source               = ""
        Destination          = ""
        IgnoreFilePatterns   = @()
        IgnoreFolderPatterns = @()
        IgnoreExtensions     = @()
    }

    $section = ""

    foreach ($rawLine in Get-Content -Path $Path -Encoding UTF8) {
        $line = $rawLine.Trim()

        if (!$line -or $line.StartsWith("#")) {
            continue
        }

        if ($line.StartsWith("[") -and $line.EndsWith("]")) {
            $section = $line.TrimStart("[").TrimEnd("]")
            continue
        }

        switch ($section) {
            "Paths" {
                if ($line -match "^([^=]+)=(.*)$") {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()

                    if ($key -eq "Source") {
                        $config.Source = $value
                    }

                    if ($key -eq "Destination") {
                        $config.Destination = $value
                    }
                }
            }

            "IgnoreFileNamesOrPatterns" {
                $config.IgnoreFilePatterns += $line
            }

            "IgnoreFolderNamesOrPatterns" {
                $config.IgnoreFolderPatterns += $line
            }

            "IgnoreExtensions" {
                if (!$line.StartsWith(".")) {
                    $line = ".$line"
                }

                $config.IgnoreExtensions += $line.ToLower()
            }
        }
    }

    if (!$config.Source) {
        Write-Host "ERROR: The source path is missing." -ForegroundColor Red
        exit
    }

    if (!$config.Destination) {
        Write-Host "ERROR: The destination path is missing." -ForegroundColor Red
        exit
    }

    return $config
}

function Test-MatchPattern {
    param(
        [string]$Value,
        [array]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Value -like $pattern) {
            return $true
        }
    }

    return $false
}

function Test-FolderIgnored {
    param(
        [string]$RelativePath,
        [array]$Patterns
    )

    $directory = Split-Path $RelativePath -Parent

    if (!$directory) {
        return $false
    }

    foreach ($part in ($directory -split "[\\/]")) {
        if (Test-MatchPattern -Value $part -Patterns $Patterns) {
            return $true
        }
    }

    return $false
}

function Test-FileIgnored {
    param(
        [System.IO.FileInfo]$File,
        [string]$RelativePath,
        [System.Collections.IDictionary]$Config
    )

    if ($currentScriptPath -and $File.FullName -eq $currentScriptPath) {
        return $true
    }

    if (Test-MatchPattern -Value $File.Name -Patterns $Config.IgnoreFilePatterns) {
        return $true
    }

    if (Test-FolderIgnored -RelativePath $RelativePath -Patterns $Config.IgnoreFolderPatterns) {
        return $true
    }

    if ($Config.IgnoreExtensions -contains $File.Extension.ToLower()) {
        return $true
    }

    return $false
}

function Get-MinuteText {
    param([datetime]$Date)

    return $Date.ToString("yyyy-MM-dd HH:mm")
}

function Get-RelativeFileMap {
    param(
        [string]$Root,
        [System.Collections.IDictionary]$Config
    )

    $map = @{}

    if (!(Test-Path $Root)) {
        return $map
    }

    foreach ($file in Get-ChildItem -Path $Root -Recurse -File -Force) {
        $relativePath = $file.FullName.Substring($Root.Length).TrimStart("\")

        if (Test-FileIgnored -File $file -RelativePath $relativePath -Config $Config) {
            continue
        }

        $map[$relativePath] = $file
    }

    return $map
}

function Get-FileCompareRows {
    param(
        [string]$Source,
        [string]$Destination,
        [System.Collections.IDictionary]$Config
    )

    Write-Host "Scanning the source folder..."
    $sourceMap = Get-RelativeFileMap -Root $Source -Config $Config

    Write-Host "Scanning the destination folder..."
    $destinationMap = Get-RelativeFileMap -Root $Destination -Config $Config

    Write-Host "Comparing files..."
    $allRelativePaths = @($sourceMap.Keys + $destinationMap.Keys) | Sort-Object -Unique
    $rows = @()

    foreach ($relativePath in $allRelativePaths) {
        $sourceExists = $sourceMap.ContainsKey($relativePath)
        $destinationExists = $destinationMap.ContainsKey($relativePath)

        $sourceFile = if ($sourceExists) { $sourceMap[$relativePath] } else { $null }
        $destinationFile = if ($destinationExists) { $destinationMap[$relativePath] } else { $null }

        $folder = Split-Path $relativePath -Parent
        if (!$folder) {
            $folder = "Root"
        }

        $fileName = Split-Path $relativePath -Leaf
        $sourceDate = if ($sourceExists) { Get-MinuteText $sourceFile.LastWriteTime } else { $null }
        $destinationDate = if ($destinationExists) { Get-MinuteText $destinationFile.LastWriteTime } else { $null }

        if ($sourceExists -and $destinationExists) {
            if (
                ($sourceDate -eq $destinationDate) -and
                ($sourceFile.Length -eq $destinationFile.Length)
            ) {
                $status = "Identical"
            }
            else {
                $status = "Different"
            }

            $location = "Source folder + destination folder"
        }
        elseif ($sourceExists) {
            $status = "New"
            $location = "Source folder"
        }
        else {
            $status = "Removed"
            $location = "Destination folder"
        }

        $rows += [PSCustomObject]@{
            Folder          = $folder
            File            = $fileName
            RelativePath    = $relativePath
            Status          = $status
            Location        = $location
            SourceDate      = if ($sourceExists) { $sourceDate } else { "-" }
            DestinationDate = if ($destinationExists) { $destinationDate } else { "-" }
            SourceSize      = if ($sourceExists) { $sourceFile.Length } else { "-" }
            DestinationSize = if ($destinationExists) { $destinationFile.Length } else { "-" }
        }
    }

    return $rows
}

function Show-GlobalSummary {
    param([array]$Rows)

    Write-Host ""
    Write-Host "Global summary:" -ForegroundColor Cyan

    foreach ($status in @("Identical", "Different", "New", "Removed")) {
        $count = @($Rows | Where-Object { $_.Status -eq $status }).Count
        Write-Host ("  {0,-10} : {1}" -f $status, $count)
    }
}

function Show-FolderSummary {
    param([array]$Rows)

    Write-Host ""
    Write-Host "Summary by folder containing differences:" -ForegroundColor Cyan

    $differentRows = @($Rows | Where-Object { $_.Status -ne "Identical" })

    if ($differentRows.Count -eq 0) {
        Write-Host "  No folder contains differences."
        return
    }

    foreach (
        $group in (
            $differentRows |
            Group-Object Folder |
            Sort-Object @{ Expression = { Get-FolderSortValue $_.Name } }
        )
    ) {
        Write-Host ("  {0}" -f $group.Name) -ForegroundColor Yellow
        Write-Host (
            "    Different : {0}" -f @(
                $group.Group | Where-Object { $_.Status -eq "Different" }
            ).Count
        )
        Write-Host (
            "    New       : {0}" -f @(
                $group.Group | Where-Object { $_.Status -eq "New" }
            ).Count
        )
        Write-Host (
            "    Removed   : {0}" -f @(
                $group.Group | Where-Object { $_.Status -eq "Removed" }
            ).Count
        )
    }
}

function Get-HideIdenticalChoice {
    Write-Host ""
    Write-Host "Display identical files?"
    Write-Host "1 - Yes, display every file"
    Write-Host "2 - No, hide identical files"

    return ((Read-Host "Your choice") -eq "2")
}

function Get-FolderSortValue {
    param([string]$FolderName)

    if ($FolderName -eq "Root") {
        return "000000_Root"
    }

    return "000001_$FolderName"
}

function Get-FilteredRows {
    param(
        [array]$Rows,
        [bool]$Hide
    )

    if ($Hide) {
        return @($Rows | Where-Object { $_.Status -ne "Identical" })
    }

    return @($Rows)
}

function Show-ComparisonTable {
    param(
        [array]$Rows,
        [bool]$Hide,
        [string]$Source,
        [string]$Destination,
        [string]$RuleText = "relative path/name + date rounded to the minute + size"
    )

    $displayRows = Get-FilteredRows -Rows $Rows -Hide $Hide

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " SOURCE / DESTINATION DIFFERENCE TABLE" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Source folder      : $Source"
    Write-Host "Destination folder : $Destination"
    Write-Host "Rule               : $RuleText"

    if ($Hide) {
        Write-Host "Filter             : identical files hidden"
    }
    else {
        Write-Host "Filter             : all files displayed"
    }

    Show-GlobalSummary $Rows
    Show-FolderSummary $Rows

    if ($displayRows.Count -eq 0) {
        Write-Host "No file matches the current filter." -ForegroundColor Green
        return
    }

    foreach (
        $group in (
            $displayRows |
            Group-Object Folder |
            Sort-Object @{ Expression = { Get-FolderSortValue $_.Name } }
        )
    ) {
        Write-Host ""
        Write-Host ("--- Folder: {0} ---" -f $group.Name) -ForegroundColor Yellow

        $group.Group |
            Sort-Object Status, File |
            Select-Object `
                Status,
                File,
                Location,
                SourceDate,
                DestinationDate,
                SourceSize,
                DestinationSize |
            Format-Table -AutoSize |
            Out-Host
    }

    Write-Host ""
    Write-Host "Display completed. No changes were applied." -ForegroundColor Green
}

function Export-ComparisonCsv {
    param(
        [array]$Rows,
        [bool]$Hide,
        [string]$Root
    )

    $exportRows = Get-FilteredRows -Rows $Rows -Hide $Hide
    $csvPath = Join-Path $Root (
        "FolderPush_Differences_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    )

    $exportRows |
        Select-Object `
            @{ Name = "FolderOrder"; Expression = { Get-FolderSortValue $_.Folder } },
            Folder,
            Status,
            File,
            Location,
            SourceDate,
            DestinationDate,
            SourceSize,
            DestinationSize |
        Sort-Object FolderOrder, Status, File |
        Select-Object `
            Folder,
            Status,
            File,
            Location,
            SourceDate,
            DestinationDate,
            SourceSize,
            DestinationSize |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"

    Write-Host ""
    Write-Host "CSV export completed." -ForegroundColor Green
    Write-Host "File: $csvPath"
    Write-Host ("Exported rows: {0}" -f $exportRows.Count)
    Write-Log "CSV export: $csvPath"

    if ((Read-Host "Open the CSV file now? (y/n)") -eq "y") {
        Start-Process $csvPath
    }
}

function Get-FileHashText {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        return "-"
    }

    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Get-FileCompareRowsHash {
    param(
        [string]$Source,
        [string]$Destination,
        [System.Collections.IDictionary]$Config
    )

    Write-Host "Scanning the source folder for hash comparison..."
    $sourceMap = Get-RelativeFileMap -Root $Source -Config $Config

    Write-Host "Scanning the destination folder for hash comparison..."
    $destinationMap = Get-RelativeFileMap -Root $Destination -Config $Config

    Write-Host "Running strict SHA-256 comparison..."
    $allRelativePaths = @($sourceMap.Keys + $destinationMap.Keys) | Sort-Object -Unique
    $rows = @()
    $index = 0
    $total = $allRelativePaths.Count

    foreach ($relativePath in $allRelativePaths) {
        $index++

        if (($index % 25) -eq 0) {
            Write-Host ("Hash progress: {0}/{1}" -f $index, $total)
        }

        $sourceExists = $sourceMap.ContainsKey($relativePath)
        $destinationExists = $destinationMap.ContainsKey($relativePath)

        $sourceFile = if ($sourceExists) { $sourceMap[$relativePath] } else { $null }
        $destinationFile = if ($destinationExists) { $destinationMap[$relativePath] } else { $null }

        $folder = Split-Path $relativePath -Parent
        if (!$folder) {
            $folder = "Root"
        }

        $fileName = Split-Path $relativePath -Leaf
        $sourceDate = if ($sourceExists) { Get-MinuteText $sourceFile.LastWriteTime } else { $null }
        $destinationDate = if ($destinationExists) { Get-MinuteText $destinationFile.LastWriteTime } else { $null }

        $sourceHash = "-"
        $destinationHash = "-"

        if ($sourceExists) {
            $sourceHash = Get-FileHashText -Path $sourceFile.FullName
        }

        if ($destinationExists) {
            $destinationHash = Get-FileHashText -Path $destinationFile.FullName
        }

        if ($sourceExists -and $destinationExists) {
            if ($sourceHash -eq $destinationHash) {
                $status = "Identical"
            }
            else {
                $status = "Different"
            }

            $location = "Source folder + destination folder"
        }
        elseif ($sourceExists) {
            $status = "New"
            $location = "Source folder"
        }
        else {
            $status = "Removed"
            $location = "Destination folder"
        }

        $rows += [PSCustomObject]@{
            Folder          = $folder
            File            = $fileName
            RelativePath    = $relativePath
            Status          = $status
            Location        = $location
            SourceDate      = if ($sourceExists) { $sourceDate } else { "-" }
            DestinationDate = if ($destinationExists) { $destinationDate } else { "-" }
            SourceSize      = if ($sourceExists) { $sourceFile.Length } else { "-" }
            DestinationSize = if ($destinationExists) { $destinationFile.Length } else { "-" }
            SourceHash      = $sourceHash
            DestinationHash = $destinationHash
        }
    }

    return $rows
}

function Export-HashComparisonCsv {
    param(
        [array]$Rows,
        [bool]$Hide,
        [string]$Root
    )

    $exportRows = Get-FilteredRows -Rows $Rows -Hide $Hide
    $csvPath = Join-Path $Root (
        "FolderPush_Hash_SHA256_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss")
    )

    $exportRows |
        Select-Object `
            @{ Name = "FolderOrder"; Expression = { Get-FolderSortValue $_.Folder } },
            Folder,
            Status,
            File,
            Location,
            SourceDate,
            DestinationDate,
            SourceSize,
            DestinationSize,
            SourceHash,
            DestinationHash |
        Sort-Object FolderOrder, Status, File |
        Select-Object `
            Folder,
            Status,
            File,
            Location,
            SourceDate,
            DestinationDate,
            SourceSize,
            DestinationSize,
            SourceHash,
            DestinationHash |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"

    Write-Host ""
    Write-Host "SHA-256 CSV export completed." -ForegroundColor Green
    Write-Host "File: $csvPath"
    Write-Host ("Exported rows: {0}" -f $exportRows.Count)
    Write-Log "SHA-256 CSV export: $csvPath"

    if ((Read-Host "Open the CSV file now? (y/n)") -eq "y") {
        Start-Process $csvPath
    }
}

function Get-HashModeActionChoice {
    Write-Host ""
    Write-Host "SHA-256 mode: what would you like to do?"
    Write-Host "1 - Display the table"
    Write-Host "2 - Export the CSV file"
    Write-Host "3 - Display the table and export the CSV file"

    return (Read-Host "Your choice")
}

function Confirm-Action {
    param([string]$Message)

    return ((Read-Host "$Message (y/n)") -eq "y")
}

function Show-ActionSummary {
    param(
        [array]$Rows,
        [string]$Title
    )

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Yellow
    Write-Host $Title -ForegroundColor Yellow
    Write-Host "===============================================" -ForegroundColor Yellow
    Write-Host (
        "New files to copy: {0}" -f @(
            $Rows | Where-Object { $_.Status -eq "New" }
        ).Count
    )
    Write-Host (
        "Different files to overwrite: {0}" -f @(
            $Rows | Where-Object { $_.Status -eq "Different" }
        ).Count
    )
    Write-Host (
        "Files to back up and remove from the destination: {0}" -f @(
            $Rows | Where-Object { $_.Status -eq "Removed" }
        ).Count
    )
    Write-Host ""
}

function Copy-RelativeFile {
    param(
        [string]$RelativePath,
        [string]$Source,
        [string]$Destination
    )

    $sourcePath = Join-Path $Source $RelativePath
    $destinationPath = Join-Path $Destination $RelativePath
    $destinationDirectory = Split-Path $destinationPath -Parent

    if (!(Test-Path $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    Copy-Item -Path $sourcePath -Destination $destinationPath -Force
    Write-Log "Copied: $RelativePath"
}

function New-BackupRoot {
    param([string]$Root)

    $backupRoot = Join-Path (
        Join-Path $Root "FolderPush_Backup"
    ) (
        Get-Date -Format "yyyyMMdd_HHmmss"
    )

    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Write-Log "Backup folder: $backupRoot"

    return $backupRoot
}

function Backup-AndRemoveFile {
    param(
        [string]$RelativePath,
        [string]$Destination,
        [string]$Backup
    )

    $sourcePath = Join-Path $Destination $RelativePath

    if (!(Test-Path $sourcePath)) {
        return
    }

    $backupPath = Join-Path $Backup $RelativePath
    $backupDirectory = Split-Path $backupPath -Parent

    if (!(Test-Path $backupDirectory)) {
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    }

    Move-Item -Path $sourcePath -Destination $backupPath -Force
    Write-Log "Backed up and removed: $RelativePath"
}

function Invoke-CopyRows {
    param(
        [array]$Rows,
        [string]$Source,
        [string]$Destination
    )

    foreach ($row in $Rows) {
        Copy-RelativeFile `
            -RelativePath $row.RelativePath `
            -Source $Source `
            -Destination $Destination

        Write-Host ("Copied: {0}" -f $row.RelativePath)
    }
}

function Invoke-RemoveRows {
    param(
        [array]$Rows,
        [string]$Destination,
        [string]$Root
    )

    if ($Rows.Count -eq 0) {
        return
    }

    $backupRoot = New-BackupRoot -Root $Root
    Write-Host "Backup folder: $backupRoot" -ForegroundColor Yellow

    foreach ($row in $Rows) {
        Backup-AndRemoveFile `
            -RelativePath $row.RelativePath `
            -Destination $Destination `
            -Backup $backupRoot

        Write-Host ("Backed up and removed: {0}" -f $row.RelativePath)
    }
}

function Show-Menu {
    Write-Host ""
    Write-Host "What would you like to do?"
    Write-Host ""
    Write-Host "1 - Copy only new files from the source folder to the destination folder"
    Write-Host "2 - Copy new files and overwrite different files in the destination folder"
    Write-Host "3 - Back up and remove extra files from the destination folder"
    Write-Host "4 - Full synchronization: copy + overwrite + backup/removal"
    Write-Host "5 - Cancel"
    Write-Host "6 - Interactive mode: choose an action for each file"
    Write-Host "7 - Display the source / destination difference table without making changes"
    Write-Host "8 - Export the difference table to CSV without making changes"
    Write-Host "9 - Run a strict SHA-256 verification without making changes"
    Write-Host ""
}

Initialize-Log -Root $scriptDirectory

$config = Read-FolderPushConfig -Path $configPath
$source = $config.Source
$destination = $config.Destination

Write-Host ""
Write-Host "Source folder      : $source"
Write-Host "Destination folder : $destination"
Write-Host "Configuration      : $configPath"
Write-Host "Log file           : $logPath"
Write-Host ""

Write-Log "Source: $source"
Write-Log "Destination: $destination"

if (!(Test-Path $source)) {
    Write-Host "ERROR: The source folder does not exist." -ForegroundColor Red
    Write-Log "Source folder not found"
    exit
}

if (!(Test-Path $destination)) {
    Write-Host "The destination folder does not exist. Creating it..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Write-Log "Destination folder created"
}

$rows = @(
    Get-FileCompareRows `
        -Source $source `
        -Destination $destination `
        -Config $config
)

Show-GlobalSummary $rows
Show-FolderSummary $rows
Show-Menu

$choice = Read-Host "Your choice"
Write-Log "Selected mode: $choice"

switch ($choice) {
    "1" {
        $rowsToCopy = @($rows | Where-Object { $_.Status -eq "New" })

        Show-ActionSummary `
            -Rows $rowsToCopy `
            -Title "PLANNED ACTION: COPY NEW FILES"

        if (Confirm-Action "Confirm copying the new files") {
            Invoke-CopyRows `
                -Rows $rowsToCopy `
                -Source $source `
                -Destination $destination

            Write-Host "Copy completed." -ForegroundColor Green
        }
        else {
            Write-Host "Action cancelled."
        }
    }

    "2" {
        $rowsToCopy = @(
            $rows |
            Where-Object {
                $_.Status -eq "New" -or
                $_.Status -eq "Different"
            }
        )

        Show-ActionSummary `
            -Rows $rowsToCopy `
            -Title "PLANNED ACTION: COPY AND OVERWRITE"

        if (Confirm-Action "Confirm copying and overwriting") {
            Invoke-CopyRows `
                -Rows $rowsToCopy `
                -Source $source `
                -Destination $destination

            Write-Host "Copy and overwrite completed." -ForegroundColor Green
        }
        else {
            Write-Host "Action cancelled."
        }
    }

    "3" {
        $rowsToRemove = @(
            $rows | Where-Object { $_.Status -eq "Removed" }
        )

        Show-ActionSummary `
            -Rows $rowsToRemove `
            -Title "PLANNED ACTION: BACK UP AND REMOVE FROM DESTINATION"

        if (Confirm-Action "Confirm backing up and removing the files") {
            Invoke-RemoveRows `
                -Rows $rowsToRemove `
                -Destination $destination `
                -Root $scriptDirectory

            Write-Host "Backup and removal completed." -ForegroundColor Green
        }
        else {
            Write-Host "Action cancelled."
        }
    }

    "4" {
        $rowsToCopy = @(
            $rows |
            Where-Object {
                $_.Status -eq "New" -or
                $_.Status -eq "Different"
            }
        )

        $rowsToRemove = @(
            $rows | Where-Object { $_.Status -eq "Removed" }
        )

        Show-ActionSummary `
            -Rows @($rowsToCopy + $rowsToRemove) `
            -Title "PLANNED ACTION: FULL SYNCHRONIZATION"

        if (Confirm-Action "Confirm the full synchronization") {
            Invoke-CopyRows `
                -Rows $rowsToCopy `
                -Source $source `
                -Destination $destination

            Invoke-RemoveRows `
                -Rows $rowsToRemove `
                -Destination $destination `
                -Root $scriptDirectory

            Write-Host "Synchronization completed." -ForegroundColor Green
        }
        else {
            Write-Host "Action cancelled."
        }
    }

    "5" {
        Write-Host "No changes were applied."
    }

    "6" {
        $backupRoot = $null

        foreach (
            $row in (
                $rows |
                Where-Object { $_.Status -ne "Identical" } |
                Sort-Object Folder, File
            )
        ) {
            Write-Host ""
            Write-Host ("[{0}] {1}" -f $row.Status, $row.RelativePath)

            if ($row.Status -eq "Removed") {
                if (Confirm-Action "Back up and remove this file from the destination") {
                    if (!$backupRoot) {
                        $backupRoot = New-BackupRoot -Root $scriptDirectory
                        Write-Host "Backup folder: $backupRoot"
                    }

                    Backup-AndRemoveFile `
                        -RelativePath $row.RelativePath `
                        -Destination $destination `
                        -Backup $backupRoot
                }
            }
            else {
                if (Confirm-Action "Copy this file to the destination") {
                    Copy-RelativeFile `
                        -RelativePath $row.RelativePath `
                        -Source $source `
                        -Destination $destination
                }
            }
        }

        Write-Host "Interactive mode completed."
    }

    "7" {
        $hideIdentical = Get-HideIdenticalChoice

        Show-ComparisonTable `
            -Rows $rows `
            -Hide $hideIdentical `
            -Source $source `
            -Destination $destination
    }

    "8" {
        $hideIdentical = Get-HideIdenticalChoice

        Export-ComparisonCsv `
            -Rows $rows `
            -Hide $hideIdentical `
            -Root $scriptDirectory
    }

    "9" {
        $hideIdentical = Get-HideIdenticalChoice
        $hashChoice = Get-HashModeActionChoice

        $hashRows = @(
            Get-FileCompareRowsHash `
                -Source $source `
                -Destination $destination `
                -Config $config
        )

        if ($hashChoice -eq "1") {
            Show-ComparisonTable `
                -Rows $hashRows `
                -Hide $hideIdentical `
                -Source $source `
                -Destination $destination `
                -RuleText "relative path/name + SHA-256 hash"
        }
        elseif ($hashChoice -eq "2") {
            Export-HashComparisonCsv `
                -Rows $hashRows `
                -Hide $hideIdentical `
                -Root $scriptDirectory
        }
        elseif ($hashChoice -eq "3") {
            Show-ComparisonTable `
                -Rows $hashRows `
                -Hide $hideIdentical `
                -Source $source `
                -Destination $destination `
                -RuleText "relative path/name + SHA-256 hash"

            Export-HashComparisonCsv `
                -Rows $hashRows `
                -Hide $hideIdentical `
                -Root $scriptDirectory
        }
        else {
            Write-Host "Invalid SHA-256 mode choice. No changes were applied." -ForegroundColor Red
        }

        Write-Log "Mode 9 completed"
    }

    default {
        Write-Host "Invalid choice. No changes were applied." -ForegroundColor Red
    }
}

Write-Log "FolderPush finished"
