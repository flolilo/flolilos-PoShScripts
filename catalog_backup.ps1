#requires -version 3

<#
    .SYNOPSIS
        Script to back up/sync catalog(s) of Phase One's Capture One and Adobe's Lightroom.

    .DESCRIPTION
        Using 7z to fastly archive the catalog(s) to the backup-location, using robocopy to download the archive from the backup-location.

    .INPUTS
        (optional) catalog_backup.txt (encoded in UTF8)
    .OUTPUTS
        None

    .NOTES
        Version:        0.3
        Author:         flolilo
        Creation Date:  2017-09-08

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
    .PARAMETER backup_existing
        When -upDown "down" is specified, back up existing catalog(s) to an archive. 1 enables, 0 disables.
    .PARAMETER Delete
        Ask for confirmation of older 7z-archives: 2 to enable confirmation, 1 to enable confirmation w/ confirmation, 0 to disable it.

    .EXAMPLE
        catalog_backup.ps1 -upDown "up" -toProcess "C1" -Delete 1
#>

param(
    [string]$upDown="define",
    [array]$toProcess=@(),
    [string]$LR_path="",
    [string]$C1_path="",
    [string]$server_path="",
    [string]$7zipexe="C:\Program Files\7-Zip\7z.exe",
    [string]$7z_up_prefix="a",
    [string]$7z_up_suffix="-mx=0 -x!Backup",
    [string]$7z_down_prefix="x",
    [string]$7z_down_suffix="",
    [int]$backup_existing=-1,
    [int]$Delete=-1
)

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

# DEFINITION: Get user-values:
Function Get-UserValues(){
    if($script:upDown -ne "up" -and $script:upDown -ne "down"){
        while($true){
            $script:upDown = Read-Host "Upload or download catalog(s)?"
            if($script:upDown -ne "up" -and $script:upDown -ne "down"){
                Write-ColorOut "Invalid input - enter `"up`" or `"down`" (w/o quotes)" -ForegroundColor Magenta
                continue
            }else{
                break
            }
        }
    }
    if($script:toProcess.Length -lt 1){
        while($true){
            $separator = ","
            $option = [System.StringSplitOptions]::RemoveEmptyEntries
            $script:toProcess = (Read-Host "Which catalog(s) to process? Both: `"C1`",`"LR`"").Split($separator,$option)
            if("LR" -notin $script:toProcess -and "C1" -notin $script:toProcess){
                Write-ColorOut "Invalid input - enter `"c1`" or `"lr`" (w/o quotes). For both, enter `"c1,lr`" (or vice versa)." -ForegroundColor Magenta
                continue
            }else{
                break
            }
        }
    }
    if(("lr" -in $script:toProcess -and $script:LR_path.Length -eq 0) -or ("c1" -in $script:toProcess -and $script:C1_path.Length -eq 0) -or $script:server_path.Length -eq 0){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\catalog_backup.txt" -PathType Leaf)){
            $temp = Get-Content -LiteralPath "$($PSScriptRoot)\catalog_backup.txt" -Raw -Encoding UTF8 | ConvertFrom-StringData
            if("lr" -in $script:toProcess -and $script:LR_path.Length -eq 0){
                $script:LR_path = $temp.LR_path
            }
            if("c1" -in $script:toProcess -and $script:C1_path.Length -eq 0){
                $script:C1_path = $temp.C1_path
            }
            if($script:server_path.Length -eq 0){
                $script:server_path = $temp.server_path
            }
        }else{
            if("lr" -in $script:toProcess -and $script:LR_path.Length -eq 0){
                try{[string]$script:LR_path = Read-Host "Enter path to LR's catalog"}catch{continue}
            }
            if("c1" -in $script:toProcess -and $script:C1_path.Length -eq 0){
                try{[string]$script:C1_path = Read-Host "Enter path to C1's catalog"}catch{continue}
            }
            if($script:server_path.Length -eq 0){
                try{[string]$script:server_path = Read-Host "Enter backup-path"}catch{continue}
            }
        }
    }
    if($script:upDown -eq "down" -and $script:backup_existing -notin (0..1)){
        while($true){
            $script:backup_existing = Read-Host "Back up existing folders? (1 = yes, 0 = no)"
            if($script:backup_existing -notin (0..1)){
                Write-ColorOut "Invalid input." -ForegroundColor Magenta
                continue
            }else{
                break
            }
        }
    }
    if($script:Delete -notin (0..2)){
        while($true){
            $script:Delete = Read-Host "Delete old archives / folders? (2 = yes, 1 = yes w/ confirmation, 0 = no)"
            if($script:Delete -notin (0..2)){
                Write-ColorOut "Invalid input." -ForegroundColor Magenta
                continue
            }else{
                break
            }
        }
    }

    [switch]$script:confirm = $(if($script:Delete -eq 1){$true}else{$false})
}

Function Start-Upload(){
    param(
        [string]$catalogname,
        [string]$PathPC = $(if($catalogname -eq "C1"){$script:C1_path}elseif($catalogname -eq "LR"){$script:LR_path})
    )
    if((Test-Path -LiteralPath $script:server_path -PathType Container) -ne $true -or (Test-Path -LiteralPath $PathPC -PathType Container) -ne $true){
        Write-ColorOut "Path(s) not available - aborting script!" -ForegroundColor Red
        Start-Sound(0)
        Start-Sleep -Seconds 5
        Exit
    }else{
        if($script:Delete -ne 0){
            Write-ColorOut "Scanning for and removing old $catalogname-backups in $script:server_path ..." -ForegroundColor Cyan
            Get-ChildItem -Path "$script:server_path\_Picture_Catalog_$($catalogname)_*" -Filter *.7z -File | ForEach-Object {
                Remove-Item $_.FullName -Confirm:$script:confirm
            }
        }
        Start-Sleep -Milliseconds 250
        Write-ColorOut "7zipping new $catalogname-backup to $script:server_path ..." -ForegroundColor Cyan
        $archive_name = "_Picture_Catalog_$($catalogname)_$(Get-Date -Format "yyyy-MM-dd").7z"
        Start-Process -FilePath $script:7zipexe -ArgumentList "$script:7z_up_prefix `"$script:server_path\$archive_name`" `"$PathPC\*`" $script:7z_up_suffix" -NoNewWindow -Wait
    }
}

Function Start-Download(){
    param(
        [string]$catalogname,
        [string]$PathPC = $(if($catalogname -eq "C1"){$script:C1_path}elseif($catalogname -eq "LR"){$script:LR_path})
    )
    if((Test-Path -LiteralPath $script:server_path -PathType Container) -ne $true -or (Test-Path -LiteralPath $PathPC -PathType Container) -ne $true){
        Write-ColorOut "Path(s) not available - aborting script!" -ForegroundColor Red
        Start-Sound(0)
        Start-Sleep -Seconds 5
        Exit
    }else{
        Write-ColorOut "Scanning for $catalogname-backups in $script:server_path ..." -ForegroundColor Cyan
        [array]$archive = Get-ChildItem -Path "$script:server_path\_Picture_Catalog_$($catalogname)_*" -Filter *.7z -File | ForEach-Object {
            [PSCustomObject]@{
                fullpath = $_.FullName
                name = $_.Name
            }
        }
        if($archive.Length -gt 1){
            Write-ColorOut "More than one LR-catalog-archive found:" -ForegroundColor Magenta
            Write-ColorOut $archive.name -ForegroundColor Yellow
            $archive | Sort-Object -Property Name -Descending
            $archive
            $archive = $archive[0]
            Write-ColorOut "Only using " -NoNewLine -ForegroundColor Cyan
            Write-ColorOut $archive.name
            Pause
        }elseif($archive.Length -lt 1){
            Write-ColorOut "No Catalog-Backups found - aborting!" -ForegroundColor Red
            Pause
            Exit
        }

        if($script:backup_existing -eq 1){
            Write-ColorOut "Backing up existing files in $PathPC" -ForegroundColor Cyan
            $archive_name = "_BACKUP_-_Picture_Catalog_$($catalogname)_$(Get-Date -Format "yyyy-MM-dd").7z"
            Start-Process -FilePath $script:7zipexe -ArgumentList "$script:7z_up_prefix `"$script:PathPC\$archive_name`" `"$PathPC\*`" $script:7z_up_suffix" -NoNewWindow -Wait
        }
        Write-ColorOut "Deleting existing files in $PathPC" -ForegroundColor Cyan
        # Deleting old catalog-files on computer:
        Get-ChildItem -Path $PathPC -Recurse -File -Exclude *.7z | Remove-Item -Confirm:$confirm
        Get-ChildItem -Path $PathPC -Recurse -Directory | Remove-Item -Confirm:$confirm

        Write-ColorOut "Starting Copying" -ForegroundColor Cyan
        Start-Process -FilePath $script:7zipexe -ArgumentList "$script:7z_down_prefix `"$($archive.fullpath)`" -o`"$PathPC`" $script:7z_down_suffix" -NoNewWindow -Wait
    }
}

Function Start-Everything(){
    Start-RSJob -Name "PreventStandby" -Throttle 1 -ScriptBlock {
        while($true){
            $MyShell = New-Object -com "Wscript.Shell"
            $MyShell.sendkeys("{F15}")
            Start-Sleep -Seconds 300
        }
    } | Out-Null

    Get-UserValues
    for($i=0; $i -lt $script:toProcess.Length; $i++){
        if($script:upDown -eq "up"){  
            Start-Upload -catalogname $script:toProcess[$i]
        }elseif($script:upDown -eq "down"){
            Start-Download -catalogname $script:toProcess[$i]
        }
    }

    # DEFINITION: clean up:
    Get-RSJob | Stop-RSJob
    Start-Sleep -Milliseconds 5
    Get-RSJob | Remove-RSJob

    Start-Sound(1)
    Pause
}

Start-Everything