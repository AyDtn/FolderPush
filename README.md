# FolderPush

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

[Version française](README.fr.md)

PowerShell script used to synchronize a work folder with a public folder.

The goal is simple: keep a work folder where files can be edited freely, then push a clean version to another folder intended to be published, shared or used as a stable version.

This script is not intended to replace Git. It is more of a local synchronization layer between two folders, with a workflow close to a `push`, but without version history.

## Principle

The script works with two folders:

```text
Work folder  ->  Public folder
```

The work folder is considered the main source.

The public folder is the destination folder. It can be updated in several ways depending on the need:

```text
copy new files
update modified files
delete files that no longer exist in the source
fully synchronize both folders
choose actions file by file
```

## Features

The script can:

```text
preview differences before applying changes
copy new files only
copy and overwrite modified files
delete extra files from the public folder
run a full synchronization
manually choose the action to apply for each file
automatically ignore selected PowerShell files
```

The preview uses `robocopy`, which gives a quick overview of the differences between the two folders.  \
Robocopy was also chosen because it is natively available on Windows 10 and Windows 11, allowing the script to be used without additional installation or specific administrator rights.

## Available modes

When launched, the script offers several choices:

```text
1 - Copy new files only
2 - Copy new files and overwrite modified files
3 - Delete extra files from the public folder only
4 - Full synchronization: copy + overwrite + delete
5 - Cancel
6 - Interactive mode: choose file by file
```

## Interactive mode

The interactive mode allows files to be handled one by one.

It distinguishes three main cases:

```text
[NEW]
File present in the work folder but missing from the public folder.

[MODIFIED]
File present in both folders, but with a different size or date.

[DELETED FROM SOURCE / PRESENT IN PUBLIC]
File missing from the work folder but still present in the public folder.
```

For each detected file, the script asks for confirmation before applying the action.

Example:

```text
[MODIFIED] index.html

Work version:
  Date : 11/05/2026 01:34:12
  Size : 15420 bytes

Public version:
  Date : 10/05/2026 23:18:45
  Size : 15420 bytes

Overwrite the public file with the work version? (y/n)
```

## Ignored files

The script automatically ignores some files to avoid copying the synchronization script itself into the public folder.

By default, files matching the following patterns are ignored:

```powershell
FolderPush*.ps1
Push-dossier-*.ps1
```

The currently running script is also excluded automatically, even if its name changes.

This keeps the public folder clean and avoids sending the PowerShell synchronization file to the destination folder.

## Configuration

The two main paths are defined at the beginning of the script:

```powershell
$source = "C:\Users\Aymeric\Documents\MonProjetTravail"
$destination = "C:\Users\Aymeric\Documents\MonProjetPublic"
```

Modify these two variables according to your own folder structure.

Example:

```powershell
$source = "C:\Users\Aymeric\Documents\Obsidian\WorkVault"
$destination = "C:\Users\Aymeric\Documents\Public\StableVault"
```

## Usage

From PowerShell, go to the folder containing the script:

```powershell
cd "C:\path\to\the\script"
```

Then run:

```powershell
.\FolderPush.ps1
```

If PowerShell script execution is blocked on the machine, it may be necessary to temporarily allow execution for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run the script again.

## Important behavior

Choice `4 - Full synchronization` uses a mirror logic.

This means that the public folder becomes identical to the work folder:

```text
new files are copied
modified files are overwritten
files missing from the source are deleted from the public folder
```

This mode is useful for publishing a clean version, but it should be used after checking the preview.

## Use cases

This script can be useful to:

```text
maintain a public folder from a work folder
publish a stable version of an Obsidian folder
separate a draft workspace from a clean workspace
prepare a folder to send, share or archive
update a local folder without using Git
```

## Limitations

This script does not provide:

```text
version history
branches
automatic rollback
advanced conflict management
```

For these needs, Git remains more appropriate.

This script is intentionally simple and local. Its purpose is mainly to avoid manual folder copies while keeping basic control over copied, modified and deleted files.
