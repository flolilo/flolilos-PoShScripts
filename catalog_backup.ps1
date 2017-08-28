#requires -version 3

<#
    .SYNOPSIS
        Script to back up/sync catalog(s) of Phase One's Capture One and Adobe's Lightroom.

    .DESCRIPTION
        Using 7z to fastly archive the catalog(s) to the backup-location, using robocopy to download the archive from the backup-location.

    .INPUTS
        None
    .OUTPUTS
        None

    .NOTES
        Version:        0.1
        Author:         flolilo
        Creation Date:  2017-08-18 (GitHub release)

    .PARAMETER upDown
        Defines if catalogs will be backed up or if backup will be restored. Choice: "up" or "down".
    .PARAMETER toProcess
        Which catalog(s) are to process. Choice: LR, C1, or both ("LR","C1")
    .PARAMETER LR_path
        Path to Lightroom's catalog
    .PARAMETER C1_path
        Path to Capture One's catalog
    .PARAMETER server_path
        Path to backup location
    .PARAMETER 7zipexe
        Path to 7z.exe
    .PARAMETER 7z_up_prefix
        Beginning of 7zip command code (upstream)
    .PARAMETER 7z_up_suffix
        Ending of 7z command code (upstream)
    .PARAMETER 7z_down_prefix
        Beginning of 7zip command code (downstream)
    .PARAMETER 7z_down_suffix
        Ending of 7z command code (downstream)
    .PARAMETER rc_switches
        Robocopy command code switches
    .PARAMETER confirmDelete
        Ask for confirmation of older 7z-archives: 1 to enable confirmation, 0 to disable it.

    .EXAMPLE
        catalog_backup.ps1 -upDown "up" -toProcess "C1" -confirmDelete 1
#>

# TODO: kick out robocopy: just unpack 7z-archive to computer. TODO:
param(
    [string]$upDown="define",
    [array]$toProcess=@(),
    [string]$LR_path="D:\Eigene_Bilder\_CANON\_Picture_Catalogs\Lightroom",
    [string]$C1_path="D:\Eigene_Bilder\_CANON\_Picture_Catalogs\Capture_One",
    [string]$server_path="\\192.168.0.2\_Flo\Eigene_Bilder\_CANON",
    [string]$7zipexe="C:\Program Files\7-Zip\7z.exe",
    [string]$7z_up_prefix="a",
    [string]$7z_up_suffix="-mx=0",
    [string]$7z_down_prefix="x",
    [string]$7z_down_suffix="",
    [string]$rc_switches="/J /R:5 /W:15",
    [int]$confirmDelete=-1
)

#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

# Checking if PoshRSJob is installed:
if (-not (Get-Module -ListAvailable -Name PoshRSJob)){
    Write-ColorOut "Module RSJob (https://github.com/proxb/PoshRSJob) is required, but it seemingly isn't installed - please start PowerShell as administrator and run`t" -ForegroundColor Red
    Write-ColorOut "Install-Module -Name PoshRSJob" -ForegroundColor DarkYellow
    Pause
    Exit
}

# DEFINITION: Making Write-Host much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-Host
        
        .DESCRIPTION
            Using the [Console]-commands to make everything faster.

        .NOTES
            Date: 2018-08-22
        
        .PARAMETER Object
            String to write out
        
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.
        
        .EXAMPLE
            Write-ColorOut "Hello World!" -ForegroundColor Green -NoNewLine
    #>
    param(
        [string]$Object,
        [string]$ForegroundColor=[Console]::ForegroundColor,
        [string]$BackgroundColor=[Console]::BackgroundColor,
        [switch]$NoNewLine=$false
    )
    $old_fg_color = [Console]::ForegroundColor
    $old_bg_color = [Console]::BackgroundColor
    
    if($ForeGroundColor -ne $old_fg_color){[Console]::ForegroundColor = $ForeGroundColor}
    if($BackgroundColor -ne $old_bg_color){[Console]::BackgroundColor = $BackgroundColor}

    if($NoNewLine -eq $false){
        [Console]::WriteLine($Object)
    }else{
        [Console]::Write($Object)
    }
    
    if($ForeGroundColor -ne $old_fg_color){[Console]::ForegroundColor = $old_fg_color}
    if($BackgroundColor -ne $old_bg_color){[Console]::BackgroundColor = $old_bg_color}
}

# DEFINITION: For the auditory experience:
Function Start-Sound($success){
    <#
    .SYNOPSIS
        Gives auditive feedback for fails and successes
    
    .DESCRIPTION
        Uses SoundPlayer and Windows's own WAVs to play sounds.

    .NOTES
        Date: 2018-08-22

    .PARAMETER success
        If 1 it plays Windows's "tada"-sound, if 0 it plays Windows's "chimes"-sound.
    
    .EXAMPLE
        For success: Start-Sound(1)
    #>
    $sound = New-Object System.Media.SoundPlayer -ErrorAction SilentlyContinue
    if($success -eq 1){
        $sound.SoundLocation = "C:\Windows\Media\tada.wav"
    }else{
        $sound.SoundLocation = "C:\Windows\Media\chimes.wav"
    }
    $sound.Play()
}

Start-RSJob -Name "PreventStandby" -Throttle 1 -ScriptBlock {
    while($true){
        $MyShell = New-Object -com "Wscript.Shell"
        $MyShell.sendkeys("{F15}")
        Start-Sleep -Seconds 300
    }
} | Out-Null


if($upDown -ne "up" -and $upDown -ne "down"){
    while($true){
        $upDown = Read-Host "Upload or download catalog(s)?"
        if($upDown -ne "up" -and $upDown -ne "down"){
            continue
        }else{
            break
        }
    }
}
if($toProcess.Length -lt 1){
    while($true){
        $separator = ","
        $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $toProcess = (Read-Host "Which catalog(s) to process? Both: `"C1`",`"LR`"").Split($separator,$option)
        if("LR" -notin $toProcess -and "C1" -notin $toProcess){
            Write-ColorOut $toProcess
            continue
        }else{
            break
        }
    }
}
if($confirmDelete -notin (0..1)){
    while($true){
        $confirmDelete = Read-Host "Confirm deletion of old archives / folders? (Integer)"
        if($confirmDelete -notin (0..1)){
            continue
        }else{
            break
        }
    }
}

[switch]$confirm = $(if($confirmDelete -eq 1){$true}else{$false})
$archive_name_lr = "_Picture_Catalog_LR_$(Get-Date -Format "yyyy-MM-dd").7z"
$archive_name_c1 = "_Picture_Catalog_C1_$(Get-Date -Format "yyyy-MM-dd").7z"

if($upDown -eq "up"){  
    if("LR" -in $toProcess){
        Write-ColorOut "Scanning for and removing old LR-backups in $server_path ..." -ForegroundColor Cyan
        Get-ChildItem -Path "$server_path\_Picture_Catalog_LR_*" -Filter *.7z -File | ForEach-Object {
            Remove-Item $_.FullName -Confirm:$confirm
        }
        Start-Sleep -Milliseconds 250
        Write-ColorOut "7zipping new LR-backup to $server_path ..." -ForegroundColor Cyan
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_up_prefix `"$server_path\$archive_name_lr`" `"$LR_path\*`" $7z_up_suffix" -NoNewWindow -Wait
    }
    if("C1" -in $toProcess){
        Write-ColorOut "Scanning for and removing old C1-backups in $server_path ..." -ForegroundColor Cyan
        Get-ChildItem -Path "$server_path\_Picture_Catalog_C1_*" -Filter *.7z -File | ForEach-Object {
            Remove-Item $_.FullName -Confirm:$confirm
        }
        Start-Sleep -Milliseconds 250
        Write-ColorOut "7zipping new C1-backup to $server_path ..." -ForegroundColor Cyan
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_up_prefix `"$server_path\$archive_name_c1`" `"$C1_path\*`" $7z_up_suffix" -NoNewWindow -Wait
    }
}elseif($upDown -eq "down"){
    if("LR" -in $toProcess){
        [array]$archive_LR = Get-ChildItem -Path "$server_path\_Picture_Catalog_LR_*" -Filter *.7z -File | ForEach-Object {
            [PSCustomObject]@{
                fullpath = $_.FullName
                name = $_.Name
            }
        }
        if($archive_LR.Length -gt 1){
            Write-ColorOut "More than one file found:" -ForegroundColor Magenta
            Write-ColorOut $archive_LR.name -ForegroundColor Yellow
            Pause
        }
        Get-ChildItem -Path $LR_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process robocopy -ArgumentList " `"$(Split-Path -Path $archive_LR.fullpath -Parent)`" `"$LR_path`" `"$($archive_LR.name)`" $rc_switches" -NoNewWindow -Wait
        Get-ChildItem -Path $LR_path -Recurse -Directory | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Confirm:$confirm
        }
        Get-ChildItem -Path $LR_path -Recurse -File -Exclude *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_down_prefix `"$LR_path\$($archive_LR.name)`" -o`"$LR_path`" $7z_down_suffix" -NoNewWindow -Wait
        Get-ChildItem -Path $LR_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }

    }
    if("C1" -in $toProcess){
        $archive_C1 = Get-ChildItem -Path "$server_path\_Picture_Catalog_C1_*" -Filter *.7z -File | ForEach-Object {
            [PSCustomObject]@{
                fullpath = $_.FullName
                name = $_.Name
            }
        }
        if($archive_C1.Length -gt 1){
            Write-ColorOut "More than one file found:" -ForegroundColor Magenta
            Write-ColorOut $archive_C1.name -ForegroundColor Yellow
            Pause
        }
        Get-ChildItem -Path $C1_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process robocopy -ArgumentList " `"$(Split-Path -Path $archive_C1.fullpath -Parent)`" `"$C1_path`" `"$($archive_C1.name)`" $rc_switches" -NoNewWindow -Wait
        Get-ChildItem -Path $C1_path -Recurse -Directory | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Confirm:$confirm
        }
        Get-ChildItem -Path $C1_path -Recurse -File -Exclude *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_down_prefix `"$C1_path\$($archive_C1.name)`" -o`"$C1_path`" $7z_down_suffix" -NoNewWindow -Wait
        Get-ChildItem -Path $C1_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }

    }
}

Get-RSJob -Name "PreventStandby" | Stop-RSJob
Start-Sleep -Milliseconds 5
Get-RSJob -Name "PreventStandby" | Remove-RSJob

Start-Sound(1)
