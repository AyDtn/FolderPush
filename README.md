# FolderPush

[English](README.md) | [Français](README.fr.md)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4?logo=windows)
![License](https://img.shields.io/badge/license-MIT-green)

**FolderPush** is a PowerShell script for controlled comparison and one-way synchronization between two folders.

It keeps a **source folder** as the reference and updates a **destination folder** while allowing you to review, copy, overwrite, back up, or remove files in a controlled way.

```text
Source folder  ───────────────►  Destination folder
  reference          one-way synchronization
```

FolderPush is not a replacement for Git and does not provide version history. It is intended as a simple and readable local synchronization tool between two locations.

## Features

- recursive comparison of source and destination folders;
- detection of identical, different, new, and removed files;
- copying of new files;
- replacement of different files in the destination;
- full one-way synchronization;
- interactive file-by-file processing;
- backup of files removed from the destination instead of permanent deletion;
- external text-based configuration;
- exclusions by file name, wildcard pattern, folder, or extension;
- global summary and folder-by-folder summary;
- detailed comparison table;
- CSV export;
- strict SHA-256 content verification;
- automatic execution logs;
- automatic creation of the destination folder when it does not exist.

## How it works

The source folder is always treated as the reference.

| Status | Meaning |
|---|---|
| `Identical` | The file is considered identical in both folders. |
| `Different` | The file exists in both folders but differs according to the selected comparison method. |
| `New` | The file exists in the source but not in the destination. |
| `Removed` | The file no longer exists in the source but still exists in the destination. |

> [!IMPORTANT]
> FolderPush performs **source-to-destination** synchronization. A change made only in the destination can be overwritten by the source version.

## Comparison methods

### Fast comparison

Synchronization modes use:

- relative path;
- file name;
- last modification date rounded to the minute;
- file size.

This method is fast and avoids small timestamp differences that can occur between file systems.

### Strict SHA-256 verification

Mode `9` calculates SHA-256 hashes to compare the actual content of files.

This method is more reliable, but it can be significantly slower on large folders or large files.

> [!CAUTION]
> Copy and synchronization actions currently use the fast comparison method. SHA-256 mode is a read-only verification mode. For critical data, run mode `9` before a full synchronization.

## Requirements

- Windows 10 or Windows 11;
- Windows PowerShell 5.1 or PowerShell 7;
- read access to the source folder;
- write access to the destination folder and the script directory.

No third-party dependency or `robocopy` installation is required.

## Repository files

```text
FolderPush/
├── FolderPush.ps1
├── FolderPush_config.en.example.txt
├── FolderPush_config.fr.example.txt
├── README.md
├── README.fr.md
└── LICENSE
```

At runtime, the script always looks for:

```text
FolderPush_config.txt
```

Choose one example configuration and copy or rename it to that exact name.

English example:

```powershell
Copy-Item .\FolderPush_config.en.example.txt .\FolderPush_config.txt
```

French example:

```powershell
Copy-Item .\FolderPush_config.fr.example.txt .\FolderPush_config.txt
```

If no configuration file exists, FolderPush creates an English template and exits so you can edit it.

## Installation

Clone the repository:

```powershell
git clone https://github.com/AyDtn/FolderPush.git
cd FolderPush
```

Create the runtime configuration:

```powershell
Copy-Item .\FolderPush_config.en.example.txt .\FolderPush_config.txt
```

Then edit the source and destination paths in `FolderPush_config.txt`.

## Configuration

Example:

```ini
[Paths]
Source=C:\Path\SourceFolder
Destination=D:\Path\DestinationFolder

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

### `[Paths]`

| Key | Description |
|---|---|
| `Source` | Reference folder to scan. |
| `Destination` | Folder to update from the source. |

Paths may contain spaces and must not be surrounded by quotation marks.

### `[IgnoreFileNamesOrPatterns]`

File names or PowerShell wildcard patterns to ignore.

Examples:

```ini
FolderPush*.ps1
Thumbs*.db
*.log
```

### `[IgnoreFolderNamesOrPatterns]`

Any file located inside a matching folder is excluded.

Examples:

```ini
.git
FolderPush_Logs
FolderPush_Backup
Temp*
```

### `[IgnoreExtensions]`

File extensions to ignore:

```ini
.tmp
.bak
.old
```

The leading dot is added automatically when omitted.

> [!WARNING]
> Do not publish your real `FolderPush_config.txt` when it contains personal paths, user names, or internal network locations. Keep only the example files in the repository and add the runtime configuration to `.gitignore`.

## Usage

Open PowerShell in the project directory and run:

```powershell
.\FolderPush.ps1
```

If script execution is blocked for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\FolderPush.ps1
```

This changes the execution policy only for the current PowerShell window.

## Available modes

| Mode | Action |
|---:|---|
| `1` | Copy only new files from the source to the destination. |
| `2` | Copy new files and overwrite different files in the destination. |
| `3` | Back up and remove files that no longer exist in the source. |
| `4` | Full synchronization: copy, overwrite, back up, and remove. |
| `5` | Cancel without making changes. |
| `6` | Choose an action for each file interactively. |
| `7` | Display the comparison table without making changes. |
| `8` | Export the comparison table to CSV. |
| `9` | Run strict SHA-256 verification, with table display and/or CSV export. |

FolderPush displays a summary and asks for confirmation before global write operations.

## Backups

When a file exists in the destination but no longer exists in the source, FolderPush does not permanently delete it.

It moves the file to:

```text
FolderPush_Backup/
└── YYYYMMDD_HHMMSS/
    └── relative file path
```

The relative directory structure is preserved to simplify manual restoration.

## Logs

A log is created for each execution:

```text
FolderPush_Logs/
└── FolderPush_Log_YYYYMMDD_HHMMSS.txt
```

It records information such as:

- start and end of execution;
- source and destination paths;
- selected mode;
- copied files;
- backed-up and removed files;
- generated CSV exports.

## CSV exports

Mode `8` creates:

```text
FolderPush_Differences_YYYYMMDD_HHMMSS.csv
```

SHA-256 mode can create:

```text
FolderPush_Hash_SHA256_YYYYMMDD_HHMMSS.csv
```

CSV files use a semicolon as the delimiter.

## Recommended precautions

Before a full synchronization:

1. verify the source and destination paths;
2. review the comparison summary;
3. use mode `7` or mode `9` when in doubt;
4. make sure the source and destination folders are not identical or nested inside one another;
5. check that enough disk space is available for backups.

## Known limitations

FolderPush does not provide:

- version history;
- branches;
- merging of concurrent changes;
- bidirectional synchronization;
- synchronization of empty folders;
- automatic backup restoration;
- automatic scheduling;
- conflict resolution when both folders have been modified.

Use Git when you need versioning, branches, merging, or a complete development history.

## Recommended `.gitignore`

```gitignore
FolderPush_config.txt
FolderPush_Logs/
FolderPush_Backup/
FolderPush_Differences_*.csv
FolderPush_Hash_SHA256_*.csv
```

## License

This project is distributed under the MIT License. See [`LICENSE`](LICENSE) for details.
