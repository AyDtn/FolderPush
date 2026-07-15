# ==============================
# FolderPush - version finale
# Comparaison et synchronisation controlee source -> cible
# ==============================

$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) { $scriptDirectory = (Get-Location).Path }
$configPath = Join-Path $scriptDirectory "FolderPush_config.txt"
$currentScriptPath = $MyInvocation.MyCommand.Path
$script:logPath = $null

function Write-Log { param([string]$Message) if ($script:logPath) { Add-Content -Path $script:logPath -Value ("{0} - {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message) -Encoding UTF8 } }
function Initialize-Log { param([string]$Root) $d=Join-Path $Root "FolderPush_Logs"; if(!(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null}; $script:logPath=Join-Path $d ("FolderPush_Log_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss")); Write-Log "Demarrage" }
function New-DefaultConfigFile { param([string]$Path) @'
# FolderPush_config.txt
[Paths]
Source=C:\Chemin\DossierSource
Destination=H:\Chemin\DossierCible
[IgnoreFileNamesOrPatterns]
FolderPush*.ps1
FolderPush*.txt
Push-dossier-*.ps1
[IgnoreFolderNamesOrPatterns]
FolderPush_Logs
FolderPush_Backup
.git
[IgnoreExtensions]
.tmp
.bak
.old
'@ | Set-Content -Path $Path -Encoding UTF8 }
function Read-FolderPushConfig { param([string]$Path)
    if(!(Test-Path $Path)){New-DefaultConfigFile -Path $Path; Write-Host "Config absente. Modele cree : $Path" -ForegroundColor Yellow; exit}
    $c=[ordered]@{Source="";Destination="";IgnoreFilePatterns=@();IgnoreFolderPatterns=@();IgnoreExtensions=@()}; $section=""
    foreach($raw in Get-Content -Path $Path -Encoding UTF8){$l=$raw.Trim(); if(!$l -or $l.StartsWith("#")){continue}; if($l.StartsWith("[") -and $l.EndsWith("]")){$section=$l.TrimStart("[").TrimEnd("]"); continue}
        switch($section){
            "Paths" { if($l -match "^([^=]+)=(.*)$"){$k=$matches[1].Trim();$v=$matches[2].Trim(); if($k -eq "Source"){$c.Source=$v}; if($k -eq "Destination"){$c.Destination=$v}} }
            "IgnoreFileNamesOrPatterns" { $c.IgnoreFilePatterns += $l }
            "IgnoreFolderNamesOrPatterns" { $c.IgnoreFolderPatterns += $l }
            "IgnoreExtensions" { if(!$l.StartsWith(".")){$l=".$l"}; $c.IgnoreExtensions += $l.ToLower() }
        }
    }
    if(!$c.Source){Write-Host "ERREUR : Source manquante." -ForegroundColor Red; exit}; if(!$c.Destination){Write-Host "ERREUR : Destination manquante." -ForegroundColor Red; exit}; return $c
}
function Test-MatchPattern { param([string]$Value,[array]$Patterns) foreach($p in $Patterns){if($Value -like $p){return $true}} return $false }
function Test-FolderIgnored { param([string]$RelativePath,[array]$Patterns) $dir=Split-Path $RelativePath -Parent; if(!$dir){return $false}; foreach($part in ($dir -split "[\\/]")){if(Test-MatchPattern -Value $part -Patterns $Patterns){return $true}} return $false }
function Test-FileIgnored { param([System.IO.FileInfo]$File,[string]$RelativePath,[hashtable]$Config) if($currentScriptPath -and $File.FullName -eq $currentScriptPath){return $true}; if(Test-MatchPattern -Value $File.Name -Patterns $Config.IgnoreFilePatterns){return $true}; if(Test-FolderIgnored -RelativePath $RelativePath -Patterns $Config.IgnoreFolderPatterns){return $true}; if($Config.IgnoreExtensions -contains $File.Extension.ToLower()){return $true}; return $false }
function Get-MinuteText { param([datetime]$Date) return $Date.ToString("yyyy-MM-dd HH:mm") }
function Get-RelativeFileMap { param([string]$Root,[hashtable]$Config) $m=@{}; if(!(Test-Path $Root)){return $m}; foreach($f in Get-ChildItem -Path $Root -Recurse -File -Force){$r=$f.FullName.Substring($Root.Length).TrimStart("\"); if(Test-FileIgnored -File $f -RelativePath $r -Config $Config){continue}; $m[$r]=$f}; return $m }
function Get-FileCompareRows { param([string]$Source,[string]$Destination,[hashtable]$Config)
    Write-Host "Analyse du dossier source..."; $sm=Get-RelativeFileMap -Root $Source -Config $Config
    Write-Host "Analyse du dossier cible..."; $dm=Get-RelativeFileMap -Root $Destination -Config $Config
    Write-Host "Comparaison en cours..."; $all=@($sm.Keys+$dm.Keys)|Sort-Object -Unique; $rows=@()
    foreach($r in $all){$se=$sm.ContainsKey($r);$de=$dm.ContainsKey($r);$sf=if($se){$sm[$r]}else{$null};$df=if($de){$dm[$r]}else{$null};$folder=Split-Path $r -Parent; if(!$folder){$folder="Racine"};$name=Split-Path $r -Leaf;$sd=if($se){Get-MinuteText $sf.LastWriteTime}else{$null};$dd=if($de){Get-MinuteText $df.LastWriteTime}else{$null}
        if($se -and $de){if(($sd -eq $dd) -and ($sf.Length -eq $df.Length)){$etat="Identique"}else{$etat="Different"};$lieu="Dossier source + dossier cible"} elseif($se){$etat="Nouveau";$lieu="Dossier source"} else {$etat="Supprime";$lieu="Dossier cible"}
        $rows += [PSCustomObject]@{Dossier=$folder;Fichier=$name;CheminRelatif=$r;Etat=$etat;Lieu=$lieu;DateSource=if($se){$sd}else{"-"};DateCible=if($de){$dd}else{"-"};TailleSource=if($se){$sf.Length}else{"-"};TailleCible=if($de){$df.Length}else{"-"}}
    }; return $rows
}
function Show-GlobalSummary { param([array]$Rows) Write-Host ""; Write-Host "Resume global :" -ForegroundColor Cyan; foreach($s in @("Identique","Different","Nouveau","Supprime")){Write-Host ("  {0,-10} : {1}" -f $s,@($Rows|Where-Object{$_.Etat -eq $s}).Count)} }
function Show-FolderSummary { param([array]$Rows) Write-Host ""; Write-Host "Resume par dossier contenant des differences :" -ForegroundColor Cyan; $d=@($Rows|Where-Object{$_.Etat -ne "Identique"}); if($d.Count -eq 0){Write-Host "  Aucun dossier avec difference.";return}; foreach($g in ($d|Group-Object Dossier|Sort-Object @{Expression={Get-FolderSortValue $_.Name}})){Write-Host ("  {0}" -f $g.Name) -ForegroundColor Yellow; Write-Host ("    Different : {0}" -f @($g.Group|Where-Object{$_.Etat -eq "Different"}).Count); Write-Host ("    Nouveau   : {0}" -f @($g.Group|Where-Object{$_.Etat -eq "Nouveau"}).Count); Write-Host ("    Supprime  : {0}" -f @($g.Group|Where-Object{$_.Etat -eq "Supprime"}).Count)} }
function Get-HideIdenticalChoice { Write-Host ""; Write-Host "Afficher les fichiers identiques ?"; Write-Host "1 - Oui, afficher tous les fichiers"; Write-Host "2 - Non, cacher les fichiers identiques"; return ((Read-Host "Votre choix") -eq "2") }

function Get-FolderSortValue {
    param([string]$FolderName)
    if ($FolderName -eq "Racine") { return "000000_Racine" }
    return "000001_$FolderName"
}

function Get-FilteredRows { param([array]$Rows,[bool]$Hide) if($Hide){return @($Rows|Where-Object{$_.Etat -ne "Identique"})}; return @($Rows) }
function Show-ComparisonTable { param([array]$Rows,[bool]$Hide,[string]$Source,[string]$Destination,[string]$RuleText="chemin/nom + date a la minute + taille") $dr=Get-FilteredRows -Rows $Rows -Hide $Hide; Write-Host ""; Write-Host "===============================================" -ForegroundColor Cyan; Write-Host " TABLEAU DES DIFFERENCES SOURCE / CIBLE" -ForegroundColor Cyan; Write-Host "===============================================" -ForegroundColor Cyan; Write-Host "Dossier source : $Source"; Write-Host "Dossier cible  : $Destination"; Write-Host "Regle : $RuleText"; if($Hide){Write-Host "Filtre : fichiers identiques caches"}else{Write-Host "Filtre : tous les fichiers affiches"}; Show-GlobalSummary $Rows; Show-FolderSummary $Rows; if($dr.Count -eq 0){Write-Host "Aucun fichier a afficher avec le filtre actuel." -ForegroundColor Green; return}; foreach($g in ($dr|Group-Object Dossier|Sort-Object @{Expression={Get-FolderSortValue $_.Name}})){Write-Host ""; Write-Host ("--- Dossier : {0} ---" -f $g.Name) -ForegroundColor Yellow; $g.Group|Sort-Object Etat,Fichier|Select-Object Etat,Fichier,Lieu,DateSource,DateCible,TailleSource,TailleCible|Format-Table -AutoSize|Out-Host}; Write-Host ""; Write-Host "Affichage termine. Aucune modification n'a ete appliquee." -ForegroundColor Green }
function Export-ComparisonCsv { param([array]$Rows,[bool]$Hide,[string]$Root) $er=Get-FilteredRows -Rows $Rows -Hide $Hide; $p=Join-Path $Root ("FolderPush_Differences_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss")); $er|Select-Object @{Name="OrdreDossier";Expression={Get-FolderSortValue $_.Dossier}},Dossier,Etat,Fichier,Lieu,DateSource,DateCible,TailleSource,TailleCible|Sort-Object OrdreDossier,Etat,Fichier|Select-Object Dossier,Etat,Fichier,Lieu,DateSource,DateCible,TailleSource,TailleCible|Export-Csv -Path $p -NoTypeInformation -Encoding UTF8 -Delimiter ";"; Write-Host ""; Write-Host "Export CSV termine." -ForegroundColor Green; Write-Host "Fichier : $p"; Write-Host ("Nombre de lignes exportees : {0}" -f $er.Count); Write-Log "Export CSV : $p"; if((Read-Host "Ouvrir le fichier CSV maintenant ? (o/n)") -eq "o"){Start-Process $p} }

function Get-FileHashText { param([string]$Path) if(!(Test-Path $Path)){return "-"}; return (Get-FileHash -Path $Path -Algorithm SHA256).Hash }
function Get-FileCompareRowsHash { param([string]$Source,[string]$Destination,[hashtable]$Config)
    Write-Host "Analyse hash du dossier source..."; $sm=Get-RelativeFileMap -Root $Source -Config $Config
    Write-Host "Analyse hash du dossier cible..."; $dm=Get-RelativeFileMap -Root $Destination -Config $Config
    Write-Host "Comparaison stricte par hash SHA256 en cours..."; $all=@($sm.Keys+$dm.Keys)|Sort-Object -Unique; $rows=@(); $index=0; $total=$all.Count
    foreach($r in $all){$index++; if(($index % 25) -eq 0){Write-Host ("Hash en cours : {0}/{1}" -f $index,$total)}
        $se=$sm.ContainsKey($r);$de=$dm.ContainsKey($r);$sf=if($se){$sm[$r]}else{$null};$df=if($de){$dm[$r]}else{$null};$folder=Split-Path $r -Parent; if(!$folder){$folder="Racine"};$name=Split-Path $r -Leaf
        $sd=if($se){Get-MinuteText $sf.LastWriteTime}else{$null};$dd=if($de){Get-MinuteText $df.LastWriteTime}else{$null};$hs="-";$hd="-"
        if($se){$hs=Get-FileHashText -Path $sf.FullName}
        if($de){$hd=Get-FileHashText -Path $df.FullName}
        if($se -and $de){if($hs -eq $hd){$etat="Identique"}else{$etat="Different"};$lieu="Dossier source + dossier cible"} elseif($se){$etat="Nouveau";$lieu="Dossier source"} else {$etat="Supprime";$lieu="Dossier cible"}
        $rows += [PSCustomObject]@{Dossier=$folder;Fichier=$name;CheminRelatif=$r;Etat=$etat;Lieu=$lieu;DateSource=if($se){$sd}else{"-"};DateCible=if($de){$dd}else{"-"};TailleSource=if($se){$sf.Length}else{"-"};TailleCible=if($de){$df.Length}else{"-"};HashSource=$hs;HashCible=$hd}
    }; return $rows
}
function Export-HashComparisonCsv { param([array]$Rows,[bool]$Hide,[string]$Root) $er=Get-FilteredRows -Rows $Rows -Hide $Hide; $p=Join-Path $Root ("FolderPush_Hash_SHA256_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss")); $er|Select-Object @{Name="OrdreDossier";Expression={Get-FolderSortValue $_.Dossier}},Dossier,Etat,Fichier,Lieu,DateSource,DateCible,TailleSource,TailleCible,HashSource,HashCible|Sort-Object OrdreDossier,Etat,Fichier|Select-Object Dossier,Etat,Fichier,Lieu,DateSource,DateCible,TailleSource,TailleCible,HashSource,HashCible|Export-Csv -Path $p -NoTypeInformation -Encoding UTF8 -Delimiter ";"; Write-Host ""; Write-Host "Export CSV hash termine." -ForegroundColor Green; Write-Host "Fichier : $p"; Write-Host ("Nombre de lignes exportees : {0}" -f $er.Count); Write-Log "Export CSV hash : $p"; if((Read-Host "Ouvrir le fichier CSV maintenant ? (o/n)") -eq "o"){Start-Process $p} }
function Get-HashModeActionChoice { Write-Host ""; Write-Host "Mode hash SHA256 : que voulez-vous faire ?"; Write-Host "1 - Afficher le tableau"; Write-Host "2 - Exporter le CSV"; Write-Host "3 - Afficher le tableau et exporter le CSV"; return (Read-Host "Votre choix") }

function Confirm-Action { param([string]$Message) return ((Read-Host "$Message (o/n)") -eq "o") }
function Show-ActionSummary { param([array]$Rows,[string]$Title) Write-Host ""; Write-Host "===============================================" -ForegroundColor Yellow; Write-Host $Title -ForegroundColor Yellow; Write-Host "===============================================" -ForegroundColor Yellow; Write-Host ("Nouveaux fichiers a copier : {0}" -f @($Rows|Where-Object{$_.Etat -eq "Nouveau"}).Count); Write-Host ("Fichiers a ecraser       : {0}" -f @($Rows|Where-Object{$_.Etat -eq "Different"}).Count); Write-Host ("Fichiers a sauvegarder puis retirer de la cible : {0}" -f @($Rows|Where-Object{$_.Etat -eq "Supprime"}).Count); Write-Host "" }
function Copy-RelativeFile { param([string]$Relative,[string]$Source,[string]$Destination) $s=Join-Path $Source $Relative; $d=Join-Path $Destination $Relative; $dir=Split-Path $d -Parent; if(!(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}; Copy-Item -Path $s -Destination $d -Force; Write-Log "Copie : $Relative" }
function New-BackupRoot { param([string]$Root) $b=Join-Path (Join-Path $Root "FolderPush_Backup") (Get-Date -Format "yyyyMMdd_HHmmss"); New-Item -ItemType Directory -Path $b -Force|Out-Null; Write-Log "Backup : $b"; return $b }
function Backup-AndRemoveFile { param([string]$Relative,[string]$Destination,[string]$Backup) $s=Join-Path $Destination $Relative; if(!(Test-Path $s)){return}; $d=Join-Path $Backup $Relative; $dir=Split-Path $d -Parent; if(!(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}; Move-Item -Path $s -Destination $d -Force; Write-Log "Sauvegarde puis retrait : $Relative" }
function Invoke-CopyRows { param([array]$Rows,[string]$Source,[string]$Destination) foreach($row in $Rows){Copy-RelativeFile -Relative $row.CheminRelatif -Source $Source -Destination $Destination; Write-Host ("Copie : {0}" -f $row.CheminRelatif)} }
function Invoke-RemoveRows { param([array]$Rows,[string]$Destination,[string]$Root) if($Rows.Count -eq 0){return}; $b=New-BackupRoot -Root $Root; Write-Host "Dossier de sauvegarde : $b" -ForegroundColor Yellow; foreach($row in $Rows){Backup-AndRemoveFile -Relative $row.CheminRelatif -Destination $Destination -Backup $b; Write-Host ("Sauvegarde puis retrait : {0}" -f $row.CheminRelatif)} }
function Show-Menu { Write-Host ""; Write-Host "Que voulez-vous faire ?"; Write-Host ""; Write-Host "1 - Copier uniquement les nouveaux fichiers du dossier source vers le dossier cible"; Write-Host "2 - Copier les nouveaux fichiers et ecraser les fichiers differents dans le dossier cible"; Write-Host "3 - Sauvegarder puis retirer les fichiers en trop dans le dossier cible"; Write-Host "4 - Synchronisation complete : copie + ecrasement + sauvegarde/retrait"; Write-Host "5 - Annuler"; Write-Host "6 - Mode interactif : choisir fichier par fichier"; Write-Host "7 - Afficher le tableau des differences source / cible, sans modification"; Write-Host "8 - Exporter le tableau des differences en CSV, sans modification"; Write-Host "9 - Verification stricte par hash SHA256, sans modification"; Write-Host "" }

Initialize-Log -Root $scriptDirectory
$config=Read-FolderPushConfig -Path $configPath
$source=$config.Source; $destination=$config.Destination
Write-Host ""; Write-Host "Dossier source : $source"; Write-Host "Dossier cible  : $destination"; Write-Host "Config         : $configPath"; Write-Host "Log            : $logPath"; Write-Host ""
Write-Log "Source : $source"; Write-Log "Destination : $destination"
if(!(Test-Path $source)){Write-Host "ERREUR : le dossier source n'existe pas." -ForegroundColor Red; Write-Log "Source absente"; exit}
if(!(Test-Path $destination)){Write-Host "Le dossier cible n'existe pas. Creation..." -ForegroundColor Yellow; New-Item -ItemType Directory -Path $destination -Force|Out-Null; Write-Log "Creation cible"}
$rows=@(Get-FileCompareRows -Source $source -Destination $destination -Config $config)
Show-GlobalSummary $rows; Show-FolderSummary $rows; Show-Menu; $choice=Read-Host "Votre choix"; Write-Log "Choix : $choice"
switch($choice){
"1"{$tc=@($rows|Where-Object{$_.Etat -eq "Nouveau"}); Show-ActionSummary $tc "ACTION PREVUE : COPIE DES NOUVEAUX FICHIERS"; if(Confirm-Action "Confirmer la copie des nouveaux fichiers"){Invoke-CopyRows $tc $source $destination; Write-Host "Copie terminee." -ForegroundColor Green}else{Write-Host "Action annulee."}}
"2"{$tc=@($rows|Where-Object{$_.Etat -eq "Nouveau" -or $_.Etat -eq "Different"}); Show-ActionSummary $tc "ACTION PREVUE : COPIE ET ECRASEMENT"; if(Confirm-Action "Confirmer la copie et l'ecrasement"){Invoke-CopyRows $tc $source $destination; Write-Host "Copie et ecrasement termines." -ForegroundColor Green}else{Write-Host "Action annulee."}}
"3"{$tr=@($rows|Where-Object{$_.Etat -eq "Supprime"}); Show-ActionSummary $tr "ACTION PREVUE : SAUVEGARDE ET RETRAIT DE LA CIBLE"; if(Confirm-Action "Confirmer la sauvegarde puis le retrait"){Invoke-RemoveRows $tr $destination $scriptDirectory; Write-Host "Sauvegarde puis retrait termines." -ForegroundColor Green}else{Write-Host "Action annulee."}}
"4"{$tc=@($rows|Where-Object{$_.Etat -eq "Nouveau" -or $_.Etat -eq "Different"}); $tr=@($rows|Where-Object{$_.Etat -eq "Supprime"}); Show-ActionSummary @($tc+$tr) "ACTION PREVUE : SYNCHRONISATION COMPLETE"; if(Confirm-Action "Confirmer la synchronisation complete"){Invoke-CopyRows $tc $source $destination; Invoke-RemoveRows $tr $destination $scriptDirectory; Write-Host "Synchronisation terminee." -ForegroundColor Green}else{Write-Host "Action annulee."}}
"5"{Write-Host "Aucune modification appliquee."}
"6"{$b=$null; foreach($row in @($rows|Where-Object{$_.Etat -ne "Identique"}|Sort-Object Dossier,Fichier)){Write-Host ""; Write-Host ("[{0}] {1}" -f $row.Etat,$row.CheminRelatif); if($row.Etat -eq "Supprime"){if(Confirm-Action "Sauvegarder puis retirer ce fichier de la cible"){if(!$b){$b=New-BackupRoot $scriptDirectory; Write-Host "Dossier de sauvegarde : $b"}; Backup-AndRemoveFile $row.CheminRelatif $destination $b}} else {if(Confirm-Action "Copier ce fichier vers la cible"){Copy-RelativeFile $row.CheminRelatif $source $destination}}}; Write-Host "Mode interactif termine."}
"7"{$hide=Get-HideIdenticalChoice; Show-ComparisonTable $rows $hide $source $destination}
"8"{$hide=Get-HideIdenticalChoice; Export-ComparisonCsv $rows $hide $scriptDirectory}
"9"{$hide=Get-HideIdenticalChoice; $hashChoice=Get-HashModeActionChoice; $hashRows=@(Get-FileCompareRowsHash -Source $source -Destination $destination -Config $config); if($hashChoice -eq "1"){Show-ComparisonTable $hashRows $hide $source $destination "chemin/nom + hash SHA256"} elseif($hashChoice -eq "2"){Export-HashComparisonCsv $hashRows $hide $scriptDirectory} elseif($hashChoice -eq "3"){Show-ComparisonTable $hashRows $hide $source $destination "chemin/nom + hash SHA256"; Export-HashComparisonCsv $hashRows $hide $scriptDirectory} else {Write-Host "Choix hash invalide. Aucune modification appliquee." -ForegroundColor Red}; Write-Log "Mode 9 termine"}
default{Write-Host "Choix invalide. Aucune modification appliquee." -ForegroundColor Red}
}
Write-Log "Fin FolderPush"
