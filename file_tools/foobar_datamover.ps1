# Flo's Foobar-MP3-Copy-Script
# Foobar-Strategy: %Artist%\[%Album%\][%Track% - ]Name.mp3

<#
    .SYNOPSIS
        Renames files to ASCII-standard & moves files from artist's and album's folders to provide better file-organisation

    .DESCRIPTION
        My Foobar's convert-strategy is "%Artist%\[%Album%\][%Track% - ]Name.mp3". By doing so, some files are orphaned in their respective folders, so there are more clicks needed to get to them.
        This script will look forfiles with non-ASCII characters and rename them and then will move orphaned files up one folder at a time.

    .NOTES
        Version:        1.3
        Author:         flolilo
        Creation Date:  2017-10-31
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT:"-tags to find them.

    .PARAMETER InputPath
        Path to your MP3s.
    .PARAMETER rename
        1 enables renaming to ASCII-standard, 0 disables.
    .PARAMETER move
        1 enables moving files if they are oprhaned, 0 disables.
    .PARAMETER debug
        If enabled (by setting to 1), the script will run all commands with -Whatif

    .INPUTS
        None.
    .OUTPUTS
        None.

    .EXAMPLE
        .\foobar_datamover.ps1 -InputPath "D:\My Music" -rename 1 -move 1 -debug 0
#>
param(
    [string]$InputPath = "D:\Temp\mp3_auto",
    [int]$Renaming = 1,
    [int]$Moving = 1,
    [int]$debug = 0
)
$WhatIfPreference = $(if($debug -eq 1){$true}else{$false})

# DEFINITION: Get all error-outputs in English:
    [Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
    $OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding
    [Console]::InputEncoding = New-Object -TypeName System.Text.UTF8Encoding


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
            Date: 2018-05-22
        
        .PARAMETER Object
            String to write out
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.

        .EXAMPLE
            Just use it like Write-Host.
    #>
    param(
        [string]$Object = "Write-ColorOut was called, but no string was transfered.",

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
            Date: 2018-03-12

        .PARAMETER Success
            1 plays Windows's "tada"-sound, 0 plays Windows's "chimes"-sound.
        
        .EXAMPLE
            For success: Start-Sound 1
        .EXAMPLE
            For fail: Start-Sound 0
    #>
    param(
        [int]$Success = $(return $false)
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


# ==================================================================================================
# ==============================================================================
#    Defining specific functions:
# ==============================================================================
# ==================================================================================================

Function Start-Replacing(){
    param(
        [Parameter(Mandatory=($true))]
        [string]$ToReplace
    )

    $ToReplace = $ToReplace.Replace('&',"+").Replace("`'","").Replace("ä","ae").Replace("ö","oe").Replace("ü","ue").Replace("ß","ss").Replace(" ", "_").Replace(",","").Replace("í","i").Replace("ř","r").Replace("á","a").Replace("[","(").Replace("]",")")

    return $ToReplace
}

Function Start-Renaming(){
    param(
        [Parameter(Mandatory=($true))]
        [string]$ToRename
    )
    [int]$errorcounter = 0
    [array]$artist = @()
    [array]$mp3 = @()

    $artist = Get-ChildItem -Path $ToRename -Directory | ForEach-Object {
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            Parent = (Split-Path -Path $_.FullName -Parent)
            album = @(Get-ChildItem -Path $_.FullName -Directory | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    BaseName = $_.BaseName
                    Parent = (Split-Path -Path $_.FullName -Parent)
                }
            })
        }
    }
    $mp3 = Get-ChildItem -Path $ToRename -Filter "*.mp3" -File -Recurse | ForEach-Object {
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            Parent = (Split-Path -Path $_.FullName -Parent)
            Extension = $_.Extension
        }
    }
    $mp3 = $mp3 | Sort-Object -Property FullName,Parent,BaseName,Extension
    $mp3 | Out-Null
    $artist = $artist | Sort-Object -Property FullName,Parent,BaseName,Extension
    $artist | Out-Null
    for($i=0; $i -lt $artist.length; $i++){
        $artist[$i].album = $artist[$i].album | Sort-Object -Property FullName,Parent,BaseName,Extension
        $artist[$i].album | Out-Null
    }

    Write-ColorOut "`r`n$(Get-Date -Format "dd.MM.yy - HH:mm") - Renaming mp3s..." -ForegroundColor Cyan
    for($i=0; $i -lt $mp3.Length; $i++){
        [string]$old_mp3 = $mp3[$i].BaseName
        $old_mp3 += $mp3[$i].Extension
        [string]$new_mp3 = Start-Replacing -ToReplace $mp3[$i].BaseName
        $new_mp3 += $mp3[$i].Extension
        if($new_mp3 -notlike $old_mp3){
            Write-ColorOut "`"$old_mp3`"`t`t-> `"$new_mp3`"" -ForegroundColor Gray
            try{
                Rename-Item -Path "$($mp3[$i].Parent)\$old_mp3" -NewName "$($mp3[$i].Parent)\$new_mp3" -WhatIf:$WhatIfPreference
            }
            catch{
                Write-ColorOut "Renaming failed!" -ForegroundColor Magenta
                $errorcounter++
            }
        }Else{
            Write-ColorOut "`"$old_mp3`"`t`t== `"$new_mp3`"" -ForegroundColor DarkGreen
        }
    }
    Start-Sleep -Seconds 1

    Write-ColorOut "`r`n$(Get-Date -Format "dd.MM.yy - HH:mm") - Renaming folders..." -ForegroundColor Cyan
    for($i=0; $i -lt $artist.Length; $i++){
        for($j=0; $j -lt $artist[$i].album.Length; $j++){
            $old_album = $artist[$i].album[$j].BaseName
            $new_album = Start-Replacing -ToReplace $artist[$i].album[$j].BaseName
            if($new_album -notlike $old_album){
                Write-ColorOut "`"$old_album`"`t`t-> `"$new_album`"" -ForegroundColor Gray
                try{
                    Rename-Item -Path "$($artist[$i].album[$j].Parent)\$old_album" -NewName "$new_album" -WhatIf:$WhatIfPreference
                }
                catch{
                    Write-ColorOut "Renaming failed!" -ForegroundColor Magenta
                    $errorcounter++
                }
            }Else{
                Write-ColorOut "`"$old_album`"`t`t== `"$new_album`"" -ForegroundColor DarkGreen
            }
        }
        Start-Sleep -Milliseconds 25
        $old_artist = $artist[$i].BaseName
        $new_artist = Start-Replacing -ToReplace $artist[$i].BaseName
        if($new_artist -notlike $old_artist){
            Write-ColorOut "`"$old_artist`"`t`t-> `"$new_artist`"" -ForegroundColor Gray
            try{
                Rename-Item -Path "$($artist[$i].Parent)\$old_artist" -NewName "$new_artist" -WhatIf:$WhatIfPreference
            }
            catch{
                Write-ColorOut "Renaming failed!" -ForegroundColor Magenta
                $errorcounter++
            }
        }Else{
            Write-ColorOut "`"$old_artist`"`t`t== `"$new_artist`"" -ForegroundColor DarkGreen
        }
    }
    Start-Sleep -Seconds 1

    if($errorcounter -ne 0){
        Write-ColorOut "ERRORS ENCOUNTERED!" -ForegroundColor Magenta
        Start-Sound -Success 0
        Start-Sleep -Seconds 15
        # return $false
    }else{
        Write-ColorOut "So far, everything went fine." -ForegroundColor Green
        # return $true
    }
}

Function Start-Moving(){
    param(
        [Parameter(Mandatory=($true))]
        [string]$ToMove
    )
    Write-ColorOut "$(Get-Date -Format "dd.MM.yy - HH:mm") - Moving files..." -ForegroundColor Cyan
    [int]$errorcounter = 0
    [int]$changecounter = 100
    [int]$loop = 0

    while($changecounter -ne 0){
        $loop++
        $changecounter = 0
        [array]$artist = @()
        [array]$album = @()
        [array]$artist_mp3 = @()
        [array]$album_mp3 = @()
        Write-ColorOut "`r`nLoop $loop" -ForegroundColor Cyan

        $artist = Get-ChildItem -Path $ToMove -Directory | ForEach-Object {
            [PSCustomObject]@{
                FullName = $_.FullName
                BaseName = $_.BaseName
                album = @(Get-ChildItem -Path $_.FullName -Directory | ForEach-Object {
                    [PSCustomObject]@{
                        mp3 = @(Get-ChildItem -Path $_.FullName -Filter "*.mp3" -File -Recurse | ForEach-Object {
                            [PSCustomObject]@{
                                FullName = $_.FullName
                                Name = $_.Name
                                BaseName = $_.BaseName
                                Extension = $_.Extension
                            }
                        })
                        FullName = $_.FullName
                        BaseName = $_.BaseName
                    }
                })
                mp3 = @(Get-ChildItem -Path $_.FullName -Filter "*.mp3" -File)
            }
        }

        for($i=0; $i -lt $artist.Length; $i++){
            Write-ColorOut $artist[$i].BaseName -ForegroundColor White
            foreach($j in $artist[$i].album){
                Write-ColorOut "|---- $($j.BaseName)" -ForegroundColor Gray
                foreach($k in $j.mp3){
                    Write-ColorOut "    |---- $($k.Name)" -ForegroundColor DarkGray
                }
            }
            foreach($j in $artist[$i].mp3){
                Write-ColorOut "|---- $($j.Name)" -ForegroundColor DarkCyan
            }
        }
        Start-Sleep -Seconds 5

        for($i=0; $i -lt $artist.Length; $i++){
            if($artist[$i].album.Length -gt 1){
                for($j=0; $j -lt $artist[$i].album.Length; $j++){
                    if($artist[$i].album[$j].mp3.Length -lt 3){
                        Write-ColorOut "$($artist[$i].album[$j].BaseName)`thas $($artist[$i].album[$j].mp3.Length) mp3s - deleting album-folder." -ForegroundColor DarkGray
                        $changecounter++
                        for($k=0; $k -lt $artist[$i].album[$j].mp3.Length; $k++){
                            try{
                                Move-Item -Path $artist[$i].album[$j].mp3[$k].FullName -Destination "$($artist[$i].FullName)\$($artist[$i].album[$j].mp3[$k].BaseName)$($artist[$i].album[$j].mp3[$k].Extension)"  -WhatIf:$WhatIfPreference
                            }catch{
                                Write-ColorOut "Moving failed!" -ForegroundColor Magenta
                                $errorcounter++
                            }
                        }
                        Start-Sleep -Milliseconds 5
                        try{
                            Remove-Item $artist[$i].album[$j].FullName -WhatIf:$WhatIfPreference
                            Start-Sleep -Milliseconds 5
                        }catch{
                            Write-ColorOut "Removing failed!" -ForegroundColor Magenta
                            $errorcounter++
                        }
                    }else{
                        Write-ColorOut "$($artist[$i].BaseName)`tis okay." -ForegroundColor DarkGreen
                    }
                }
            }elseif($artist[$i].album.Length -eq 1 -and $artist[$i].mp3.Length -lt 3){
                Write-ColorOut "$($artist[$i].BaseName)`thas $($artist[$i].album.Length) album and $($artist[$i].mp3.Length) root-mp3s - deleting album-folder." -ForegroundColor Gray
                $changecounter++
                for($j=0; $j -lt $artist[$i].album[0].mp3.Length; $j++){
                    try{
                        Move-Item -Path $artist[$i].album[0].mp3[$j].FullName -Destination "$($artist[$i].FullName)\$($artist[$i].album[0].mp3[$j].Name)" -WhatIf:$WhatIfPreference
                    }catch{
                        Write-ColorOut "Moving failed!" -ForegroundColor Magenta
                        $errorcounter++
                    }
                }
                Start-Sleep -Milliseconds 5
                try{
                    Remove-Item $artist[$i].album[0].FullName -WhatIf:$WhatIfPreference
                    Start-Sleep -Milliseconds 5
                }catch{
                    Write-ColorOut "Removing failed!" -ForegroundColor Magenta
                    $errorcounter++
                }
            }elseif($artist[$i].album.Length -eq 0 -and $artist[$i].mp3.Length -lt 3){
                Write-ColorOut "$($artist[$i].BaseName)`thas $($artist[$i].album.Length) albums and $($artist[$i].mp3.Length) root-mp3s - deleting artist-folder." -ForegroundColor DarkCyan
                $changecounter++
                for($j=0; $j -lt $artist[$i].mp3.Length; $j++){
                    try{
                        Move-Item -Path $artist[$i].mp3[$j].FullName -Destination "$(Split-Path -Path $artist[$i].FullName -Parent)\$($artist[$i].BaseName)_-_$($artist[$i].mp3[$j].BaseName)$($artist[$i].mp3[$j].Extension)"  -WhatIf:$WhatIfPreference
                    }catch{
                        Write-ColorOut "Moving failed!" -ForegroundColor Magenta
                        $errorcounter++
                    }
                }
                Start-Sleep -Milliseconds 5
                try{
                    Remove-Item $artist[$i].FullName -WhatIf:$WhatIfPreference
                    Start-Sleep -Milliseconds 5
                }catch{
                    Write-ColorOut "Removing failed!" -ForegroundColor Magenta
                }
            }else{
                Write-ColorOut "$($artist[$i].BaseName)`tis okay." -ForegroundColor DarkGreen
            }
        }
        Start-Sleep -Seconds 1
    }

    if($errorcounter -ne 0){
        Write-ColorOut "ERRORS ENCOUNTERED!" -ForegroundColor Magenta
        Start-Sound -Success 0
        Start-Sleep -Seconds 15
        # return $false
    }else{
        Write-ColorOut "So far, everything went fine." -ForegroundColor Green
        # return $true
    }
}

Function Start-Everything(){
    if((Test-Path -Path $script:InputPath -PathType Container) -eq $false){
        Write-ColorOut "FOLDER NON-EXISTENT!" -ForegroundColor Red
        Start-Sleep -Seconds 2
        Exit
    }
    if($script:Renaming -eq 1){
        Start-Renaming -ToRename $script:InputPath
    }
    if($script:Moving -eq 1){
        Start-Moving -ToMove $script:InputPath
    }
    Write-ColorOut "`r`nDONE!" -ForegroundColor Green
    Start-Sound -Success 1
    Pause
}

Start-Everything
