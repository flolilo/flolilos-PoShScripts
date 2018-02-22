#requires -version 3

<#
    .SYNOPSIS
        Script to back up/sync catalog(s) of Phase One's Capture One and Adobe's Lightroom.
    .DESCRIPTION
        Using 7z to fastly archive the catalog(s) to the backup-location, using robocopy to download the archive from the backup-location.
    .NOTES
        Version:        1.2
        Author:         flolilo
        Creation Date:  2018-02-22

    .INPUTS
        (optional) catalog_backup_vars.json (encoded in UTF8).
    .OUTPUTS
        None.

    .PARAMETER upDown
        Defines if catalogs will be backed up or if backup will be restored. Choice: "up" or "down".
    .PARAMETER toProcess
        Which catalog(s) are to process. Choice: LR, C1, or both ("LR","C1").
    .PARAMETER LR_path
        Path to Lightroom's catalog. LR's default catalog path is in your Picture-library, "Lightroom".
    .PARAMETER C1_path
        Path to Capture One's catalog. C1's default catalog path is in your Picture-library, "Capture One Catalogs".
    .PARAMETER server_path
        Path to backup location.
    .PARAMETER 7zipexe
        Path to 7z.exe.
    .PARAMETER 7z_up_prefix
        Beginning of 7zip command code (upstream).
    .PARAMETER 7z_up_suffix
        Ending of 7z command code (upstream).
    .PARAMETER 7z_down_prefix
        Beginning of 7zip command code (downstream).
    .PARAMETER 7z_down_suffix
        Ending of 7z command code (downstream).
    .PARAMETER rc_switches
        Robocopy command code switches.
    .PARAMETER backup_existing
        When -upDown "down" is specified, back up existing catalog(s) to an archive. 1 enables, 0 disables.
    .PARAMETER Delete
        Ask for confirmation of older 7z-archives: 2 to enable confirmation, 1 to enable confirmation w/ confirmation, 0 to disable it.

    .EXAMPLE
        catalog_backup.ps1 -upDown "up" -toProcess "C1" -Delete 1
#>
param(
    [string]$upDown =           "define",
    [array]$toProcess =         @(),
    [string]$LR_path =          "",
    [string]$C1_path =          "",
    [string]$server_path =      "",
    [string]$7zipexe =          "C:\Program Files\7-Zip\7z.exe",
    [string]$7z_up_prefix =     "a -t7z -m0=Copy -mx0 -ms=off -ssw -sccUTF-8 -bb0",
    [string]$7z_up_suffix =     " -x!Backup",
    [string]$7z_down_prefix =   "x -aoa -bb0 -pdefault -sccUTF-8 -spf2",
    [string]$7z_down_suffix =   "",
    [int]$backup_existing =     -1,
    [int]$Delete =              -1,
    [int]$Debug =               0
)

# DEFINITION: Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding


# ==================================================================================================
# ==============================================================================
#    Defining generic functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Making Write-Host much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-Host
        .DESCRIPTION
            Using the [Console]-commands to make everything faster.
        .NOTES
            Date: 2017-10-30
        
        .PARAMETER Object
            String to write out. Mandatory, but will take every non-parametised value.
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.
        .PARAMETER Indentation
            Will move the cursor n blocks to the right, creating a possibility to indent the output without using "    " or "`t".

        .EXAMPLE
            Just use it like Write-Host.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Object,

        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")]
        [string]$ForegroundColor,

        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")]
        [string]$BackgroundColor,

        [switch]$NoNewLine=$false,

        [ValidateRange(0,48)]
        [int]$Indentation=0
    )

    if($ForegroundColor.Length -ge 3){
        $old_fg_color = [Console]::ForegroundColor
        [Console]::ForegroundColor = $ForegroundColor
    }
    if($BackgroundColor.Length -ge 3){
        $old_bg_color = [Console]::BackgroundColor
        [Console]::BackgroundColor = $BackgroundColor
    }
    if($Indentation -gt 0){
        [Console]::CursorLeft = $Indentation
    }

    if($NoNewLine -eq $false){
        [Console]::WriteLine($Object)
    }else{
        [Console]::Write($Object)
    }
    
    if($ForegroundColor.Length -ge 3){
        [Console]::ForegroundColor = $old_fg_color
    }
    if($BackgroundColor.Length -ge 3){
        [Console]::BackgroundColor = $old_bg_color
    }
}

# DEFINITION: For the auditory experience:
Function Start-Sound(){
    <#
        .SYNOPSIS
            Gives auditive feedback for fails and successes
        .DESCRIPTION
            Uses SoundPlayer and Windows's own WAVs to play sounds.
        .NOTES
            Date: 2018-10-25

        .PARAMETER Success
            1 plays Windows's "tada"-sound, 0 plays Windows's "chimes"-sound.
        
        .EXAMPLE
            For success: Start-Sound 1
        .EXAMPLE
            For fail: Start-Sound 0
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$Success
    )
    try{
        $sound = New-Object System.Media.SoundPlayer -ErrorAction stop
        if($Success -eq 1){
            $sound.SoundLocation = "C:\Windows\Media\tada.wav"
        }else{
            $sound.SoundLocation = "C:\Windows\Media\chimes.wav"
        }
        $sound.Play()
    }catch{
        Write-Output "`a"
    }
}

# DEFINITION: Start equivalent to PreventSleep.ps1:
Function Invoke-PreventSleep(){
    <#
        .NOTES
            v1.0 - 2018-02-22
    #>
    Write-ColorOut "$(Get-CurrentDate)  --  Starting preventsleep-script..." -ForegroundColor Cyan

$standby = @'
    # DEFINITION: For button-emulation:
    Write-Host "(PID = $("{0:D8}" -f $pid))" -ForegroundColor Gray
    $MyShell = New-Object -ComObject "Wscript.Shell"
    while($true){
        # DEFINITION:/CREDIT: https://superuser.com/a/1023836/703240
        $MyShell.sendkeys("{F15}")
        Start-Sleep -Seconds 90
    }
'@
    $standby = [System.Text.Encoding]::Unicode.GetBytes($standby)
    $standby = [Convert]::ToBase64String($standby)

    [int]$preventstandbyid = (Start-Process powershell -ArgumentList "-EncodedCommand $standby" -WindowStyle Hidden -PassThru).Id
    if($script:Debug -gt 0){
        Write-ColorOut "preventsleep-PID is $("{0:D8}" -f $preventstandbyid)" -ForegroundColor Gray -BackgroundColor DarkGray -Indentation 4
    }
    Start-Sleep -Milliseconds 25
    if((Get-Process -Id $preventstandbyid -ErrorVariable SilentlyContinue).count -ne 1){
        Write-ColorOut "Cannot prevent standby" -ForegroundColor Magenta -Indentation 4
        Start-Sleep -Seconds 3
    }

    return $preventstandbyid
}

# DEFINITION: Getting date and time in pre-formatted string:
Function Get-CurrentDate(){
    return $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}


# ==================================================================================================
# ==============================================================================
#    Defining specific functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Get user-values:
Function Get-UserValues(){
    Write-ColorOut "$(Get-CurrentDate)  --  Getting uservalues..." -ForegroundColor Cyan

    if($script:upDown -ne "up" -and $script:upDown -ne "down"){
        while($true){
            [string]$script:upDown = Read-Host "Upload or download catalog(s)?"
            if($script:upDown -ne "up" -and $script:upDown -ne "down"){
                Write-ColorOut "Invalid input - enter `"up`" or `"down`" (w/o quotes)" -ForegroundColor Magenta -Indentation 4
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
                Write-ColorOut "Invalid input - enter `"c1`" or `"lr`" (w/o quotes). For both, enter `"c1,lr`" (or vice versa)." -ForegroundColor Magenta -Indentation 4
                continue
            }else{
                break
            }
        }
    }
    if(("lr" -in $script:toProcess -and $script:LR_path.Length -eq 0) -or ("c1" -in $script:toProcess -and $script:C1_path.Length -eq 0) -or $script:server_path.Length -eq 0){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\catalog_backup_vars.json" -PathType Leaf)){
            $JSON = Get-Content -LiteralPath "$($PSScriptRoot)\catalog_backup_vars.json" -Raw -Encoding UTF8 | ConvertFrom-JSON
            $JSON | Out-Null

            if("lr" -in $script:toProcess -and $script:LR_path.Length -eq 0){
                $script:LR_path = $JSON.LR_path
            }
            if("c1" -in $script:toProcess -and $script:C1_path.Length -eq 0){
                $script:C1_path = $JSON.C1_path
            }
            if($script:server_path.Length -eq 0){
                $script:server_path = $JSON.server_path
            }
        }else{
            if("lr" -in $script:toProcess -and $script:LR_path.Length -eq 0){
                try{
                    [string]$script:LR_path = Read-Host "Enter path to LR's catalog. If you're confused: LR's default catalog path is $([Environment]::GetFolderPath("MyPictures"))\Lightroom.`t"
                }catch{
                    continue
                }
            }
            if("c1" -in $script:toProcess -and $script:C1_path.Length -eq 0){
                try{
                    [string]$script:C1_path = Read-Host "Enter path to C1's catalog. If you're confused: C1's default catalog path is $([Environment]::GetFolderPath("MyPictures"))\Capture One Catalogs.`t"
                }catch{
                    continue
                }
            }
            if($script:server_path.Length -eq 0){
                try{
                    [string]$script:server_path = Read-Host "Enter backup-path"
                }catch{
                    continue
                }
            }
        }
    }
    if($script:upDown -eq "down" -and $script:backup_existing -notin (0..1)){
        while($true){
            [int]$script:backup_existing = Read-Host "Back up existing folders? (1 = yes, 0 = no)"
            if($script:backup_existing -notin (0..1)){
                Write-ColorOut "Invalid input." -ForegroundColor Magenta -Indentation 4
                continue
            }else{
                break
            }
        }
    }
    if($script:Delete -notin (0..2)){
        while($true){
            [int]$script:Delete = Read-Host "Delete old archives / folders? (2 = yes, 1 = yes w/ confirmation, 0 = no)"
            if($script:Delete -notin (0..2)){
                Write-ColorOut "Invalid input." -ForegroundColor Magenta -Indentation 4
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
        [string]$catalogname
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Starting upload..." -ForegroundColor Cyan

    if($catalogname -eq "C1"){
        [string]$Catalog_Path = $script:C1_path
    }elseif($catalogname -eq "LR"){
        [string]$Catalog_Path = $script:LR_path
    }

    if((Test-Path -LiteralPath $script:server_path -PathType Container) -ne $true -or (Test-Path -LiteralPath $Catalog_Path -PathType Container) -ne $true){
        Write-ColorOut "Path(s) not available - aborting script!" -ForegroundColor Red -Indentation 4
        return $false
    }else{
        if($script:Delete -ne 0){
            Write-ColorOut "Scanning for and removing old $catalogname-backups in $script:server_path ..." -ForegroundColor Cyan -Indentation 4
            Get-ChildItem -Path "$script:server_path\_Picture_Catalog_$($catalogname)_*" -Filter *.7z -File | ForEach-Object {
                Remove-Item $_.FullName -Confirm:$script:confirm
            }
        }
        Start-Sleep -Milliseconds 250
        Write-ColorOut "7zipping new $catalogname-backup to $script:server_path ..." -ForegroundColor Cyan -Indentation 4
        [string]$archive_name = "_Picture_Catalog_$($catalogname)_$(Get-Date -Format "yyyy-MM-dd").7z"
        Pause
        Start-Process -FilePath $script:7zipexe -ArgumentList "$script:7z_up_prefix `"-w$Catalog_Path\`" `"$script:server_path\$archive_name`" `"$Catalog_Path`" $script:7z_up_suffix" -NoNewWindow -Wait
    }

    return $true
}

Function Start-Download(){
    param(
        [string]$catalogname
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Starting download..." -ForegroundColor Cyan

    if($catalogname -eq "C1"){
        [string]$Catalog_Path = $script:C1_path
    }elseif($catalogname -eq "LR"){
        [string]$Catalog_Path = $script:LR_path
    }
    
    if((Test-Path -LiteralPath $script:server_path -PathType Container) -ne $true -or (Test-Path -LiteralPath $Catalog_Path -PathType Container) -ne $true){
        Write-ColorOut "Path(s) not available - aborting script!" -ForegroundColor Red -Indentation 4
        return $false
    }else{
        if($script:backup_existing -eq 1){
            Write-ColorOut "Backing up existing files in $Catalog_Path ..." -ForegroundColor Cyan -Indentation 4
            [string]$backup_archive_name = "_BACKUP_-_PicCat_$($catalogname)_$(Get-Date -Format "yyyy-MM-dd").7z"
            Start-Process -FilePath $script:7zipexe -ArgumentList "$script:7z_up_prefix `"-w$Catalog_Path\`" `"$Catalog_Path\$backup_archive_name`" `"$Catalog_Path`" $script:7z_up_suffix" -NoNewWindow -Wait
        }

        Write-ColorOut "Scanning for $catalogname-backups in $script:server_path ..." -ForegroundColor Cyan -Indentation 4
        [array]$archive = Get-ChildItem -Path "$script:server_path\_Picture_Catalog_$($catalogname)_*" -Filter *.7z -File | ForEach-Object {
            [PSCustomObject]@{
                FullPath = $_.FullName
                Name = $_.Name
            }
        }
        if($archive.Length -gt 1){
            $archive = $archive | Sort-Object -Property Name -Descending
            $archive | Out-Null
            Write-ColorOut "More than one $catalogname-backup found:" -ForegroundColor Magenta -Indentation 4
            for($i=0; $i -lt $archive.Length; $i++){
                Write-ColorOut "$i`t- $($archive[$i].name)" -ForegroundColor Yellow -Indentation 4
            }
            [int]$select = ($archive.Length + 10)
            while($select -notin (0..($archive.Length -1))){
                [int]$select = Read-Host "Which one to use?"
            }
            $archive = $archive[$select]
            Write-ColorOut "Only using " -NoNewLine -ForegroundColor Cyan -Indentation 4
            Write-ColorOut $archive.name -Indentation 4
            Pause
        }elseif($archive.Length -lt 1){
            Write-ColorOut "No $catalogname-backups found - aborting!" -ForegroundColor Red -Indentation 4
            Pause
            return $false
        }

        Write-ColorOut "Deleting existing files in $Catalog_Path ..." -ForegroundColor Cyan
        # Deleting old catalog-files on computer:
        Get-ChildItem -Path $Catalog_Path -Recurse -File -Exclude *.7z | Remove-Item -Confirm:$confirm -Recurse
        Get-ChildItem -Path $Catalog_Path -Recurse -Directory | Remove-Item -Confirm:$confirm -Recurse

        Write-ColorOut "Starting Copying..." -ForegroundColor Cyan
        # DEFINITION: $inter tries to prevent dooubling up of catalog-path (e.g. catc1/catc1/ instead of catc1/)
        $inter = Split-Path -Path $Catalog_Path -Parent
        Start-Process -FilePath $script:7zipexe -ArgumentList "$script:7z_down_prefix `"$($archive.fullpath)`" `"-o$inter`" $script:7z_down_suffix" -NoNewWindow -Wait
    }

    return $true
}

Function Start-Everything(){
    Write-ColorOut "                                          A" -BackgroundColor DarkGray -ForegroundColor DarkGray
    Write-ColorOut "        flolilo's catalog backupper        " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "             v1.2 - 2018-02-22             " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "(PID = $("{0:D8}" -f $pid))                           `r`n" -ForegroundColor Gray -BackgroundColor DarkGray

    [int]$preventstandbyid = Invoke-PreventSleep
    Get-UserValues

    Write-ColorOut "-upDown`t`t=`t$script:upDown" -ForegroundColor Yellow -Indentation 4
    Write-ColorOut "-toProcess`t=`t$script:toProcess" -ForegroundColor Yellow -Indentation 4
    Write-ColorOut "-LR_path`t=`t$script:LR_path" -ForegroundColor Yellow -Indentation 4
    Write-ColorOut "-C1_path`t=`t$script:C1_path" -ForegroundColor Yellow -Indentation 4
    Write-ColorOut "-server_path`t=`t$script:server_path" -ForegroundColor Yellow -Indentation 4
    Start-Sleep -Seconds 5

    for($i=0; $i -lt $script:toProcess.Length; $i++){
        if($script:upDown -eq "up"){  
            if((Start-Upload -catalogname $script:toProcess[$i]) -eq $false){
                Write-ColorOut "Error in uploading $($script:toProcess[$i])!" -ForegroundColor Red -Indentation 4
                Start-Sound -Success 0
                Start-Sleep -Seconds 5
            }
            Start-Sleep -Milliseconds 50
        }elseif($script:upDown -eq "down"){
            if((Start-Download -catalogname $script:toProcess[$i]) -eq $false){
                Write-ColorOut "Error in downloading $($script:toProcess[$i])!" -ForegroundColor Red -Indentation 4
                Start-Sound -Success 0
                Start-Sleep -Seconds 5
            }
            Start-Sleep -Milliseconds 50
        }
    }

    Stop-Process -Id $preventstandbyid -Verbose

    Write-ColorOut "$(Get-CurrentDate)  --  Done!" -ForegroundColor Green
    Start-Sound -Success 1
    Pause
}

Start-Everything
