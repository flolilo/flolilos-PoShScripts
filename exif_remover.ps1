#requires -version 3

<#
    .SYNOPSIS
        Removes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.
    .DESCRIPTION
        Uses exiftool by Phil Harvey (https://sno.phy.queensu.ca/~phil/exiftool/)
    .NOTES
        Version:        1.4
        Author:         flolilo
        Creation Date:  2017-10-10

    .INPUTS
        exiftool.exe
        (optional) exif_remover_vars.json, formatted in UTF8 for copyright-values (if not provided via parameters).
    .OUTPUTS
        none.

    .PARAMETER InputPath
        Path where images should be searched and edited (default: current path of console).
    .PARAMETER AddCopyright
        Enables or disables writing of copyright-information (specified with -ArtistName and -CopyrightText).
    .PARAMETER ArtistName
        Name of artist.
    .PARAMETER CopyrightText
        Copyright-information you want to add.
    .PARAMETER ThreadCount
        How many exiftool-instances run simultaneously. Default: 8, Valid: 1-128.
    .PARAMETER Encoder
        Path to exiftool.exe.
    .PARAMETER ShowValues
        Only show copyright-values.

    .EXAMPLE
        exit_remover -AddCopyright 1 -ArtistName "John Doe" -CopyrightText "2017, by John Doe. -Encoder "C:\exiftool.exe"
#>
param(
    [string]$InputPath = "$((Get-Location).Path)",
    [switch]$AddCopyright = $false,
    [string]$ArtistName = "",
    [string]$CopyrightText = "",
    [ValidateRange(1,128)]
    [int]$ThreadCount = 8,
    [string]$Encoder = "$($PSScriptRoot)\exiftool.exe",
    [switch]$ShowValues = $false
)

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

# DEFINITION: Making Write-Host much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-Host
        .DESCRIPTION
            Using the [Console]-commands to make everything faster.
        .NOTES
            Date: 2017-10-03
        
        .PARAMETER Object
            String to write out
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Object,

        [Parameter(Mandatory=$false)]
        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")]
        [string]$ForegroundColor,

        [Parameter(Mandatory=$false)]
        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")]
        [string]$BackgroundColor,

        [switch]$NoNewLine=$false,

        [ValidateRange(0,48)]
        [int]$Indentation=0
    )

    if($ForegroundColor.Length -ge 3){
        $old_fg_color = [Console]::ForegroundColor
        [Console]::ForegroundColor = $ForeGroundColor
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
Function Start-Sound($Success){
    <#
        .SYNOPSIS
            Gives auditive feedback for fails and successes
        .DESCRIPTION
            Uses SoundPlayer and Windows's own WAVs to play sounds
        .NOTES
            Date: 2018-08-22

        .PARAMETER success
            If 1 it plays Windows's "tada"-sound, if 0 it plays Windows's "chimes"-sound.
        
        .EXAMPLE
            For success: Start-Sound(1)
    #>
    try{
        $sound = New-Object System.Media.SoundPlayer -ErrorAction stop
        if($Success -eq 1){
            $sound.SoundLocation = "C:\Windows\Media\tada.wav"
        }else{
            $sound.SoundLocation = "C:\Windows\Media\chimes.wav"
        }
        $sound.Play()
    }catch{
        Write-Host "`a"
    }
}


# ==================================================================================================
# ==============================================================================
#   Defining Functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Get user-values:
Function Get-UserValues(){
    if($script:AddCopyright -eq $true -and ($script:ArtistName.Length -lt 1 -or $script:CopyrightText.Length -lt 1)){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\exif_remover_vars.json" -PathType Leaf) -eq $true){
            $JSON = Get-Content -LiteralPath "$($PSScriptRoot)\exif_remover_vars.json" -Raw -Encoding UTF8 | ConvertFrom-JSON
            $JSON | Out-Null

            [string]$script:ArtistName = $JSON.artist_name
            [string]$script:CopyrightText = $JSON.copyright_text
        }else{
            try{
                [string]$script:ArtistName = Read-Host "Enter artist name here`t"
            }catch{
                continue
            }
            try{
                [string]$script:CopyrightText = Read-Host "Enter copyright text here`t"
            }catch{
                continue
            }
        }
    }

    # DEFINITION: Search for exiftool:
    if((Test-Path -LiteralPath $script:Encoder -PathType Leaf) -eq $false){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\exiftool.exe" -PathType Leaf) -eq $false){
            Write-ColorOut "Exiftool not found - aborting!" -ForegroundColor Red
            Start-Sound(0)
            Exit
        }else{
            [string]$script:Encoder = "$($PSScriptRoot)\exiftool.exe"
        }
    }
}

# DEFINITION: Search for files:
Function Search-Files(){
    param(
        [Parameter(Mandatory=$true)]
        [string]$InPath
    )
    $sw = [diagnostics.stopwatch]::StartNew()

    [array]$files_in = @()
    [int]$counter = 1
    $files_in = @(Get-ChildItem -LiteralPath $InPath -Include *.jpg,*.jpeg | ForEach-Object {
        if($sw.Elapsed.TotalMilliseconds -ge 750 -or $i -eq 0){
            Write-Progress -Activity "Searching JP(E)Gs..." -Status "$($counter) - $($_.BaseName)" -PercentComplete -1
            $sw.Reset()
            $sw.Start()
        }
        $counter++
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
        }
    })
    Write-Progress -Activity "Searching JP(E)Gs..." -Status "Done" -Completed

    return $files_in
}

# DEFINITION: Deleting EXIF:
Function Remove-EXIF(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$InFiles
    )
    $sw = [diagnostics.stopwatch]::StartNew()

    for($i=0; $i -lt $InFiles.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 750 -or $i -eq 0){
            Write-Progress -Activity "Deleting EXIFs..." -Status "$($i + 1)/$($InFiles.Length) - $($InFiles[$i].BaseName)" -PercentComplete ((($i + 1) / $InFiles.Length) * 100)
            $sw.Reset()
            $sw.Start()
        }

        while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -ge $script:ThreadCount){
            Start-Sleep -Milliseconds 25
        }
        Start-Process -FilePath $script:Encoder -ArgumentList " -IPTC:All= -XMP:All= -EXIF:All= -photoshop:All= -adobe:all= -overwrite_original `"$($InFiles[$i].FullName)`"" -WindowStyle Hidden
    }
    while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -gt 0){
        Start-Sleep -Milliseconds 25
    }
    Write-Progress -Activity "Deleting EXIFs..." -Status "Done" -Completed
}

# DEFINITION: Adding copyright:
Function Add-EXIF(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$InFiles
    )
    $sw = [diagnostics.stopwatch]::StartNew()

    for($i=0; $i -lt $InFiles.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 750 -or $i -eq 0){
            Write-Progress -Activity "Adding Copyright..." -Status "$($i + 1)/$($InFiles.Length) - $($InFiles[$i].BaseName)" -PercentComplete ((($i + 1) / $InFiles.Length) * 100)
            $sw.Reset()
            $sw.Start()
        }

        while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -ge $script:ThreadCount){
            Start-Sleep -Milliseconds 25
        }
        Start-Process -FilePath $script:Encoder -ArgumentList " -artist=`"$script:ArtistName`" -copyright=`"$script:CopyrightText`" -overwrite_original `"$($InFiles[$i].FullName)`"" -WindowStyle Hidden
    }

    while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -gt 0){
        Start-Sleep -Milliseconds 25
    }
    Write-Progress -Activity "Adding Copyright..." -Status "Done" -Completed
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Get-UserValues
    # DEFINITION: Show new EXIF values:
    if($script:ShowValues -eq $true){
        Write-ColorOut "Artist name:`t$script:ArtistName" -ForegroundColor Gray
        Write-ColorOut "Copyright text:`t$script:CopyrightText" -ForegroundColor DarkGray
        Pause
        Exit
    }
    if((Test-Path -LiteralPath $script:InputPath -PathType Container) -eq $true){
        [array]$inputfiles = Search-Files -InPath $script:InputPath
        Remove-EXIF -InFiles $inputfiles
        if($script:AddCopyright -eq $true){
            Start-Sleep -Milliseconds 100
            Add-EXIF -InFiles $inputfiles
        }

        Write-ColorOut "Done!" -ForegroundColor Green
        Start-Sound(1)
        if((Read-Host "Show files?") -gt 0){
            foreach($i in $inputfiles.FullName){
                Write-ColorOut $i -ForegroundColor Gray
            }
        }

    }else{
        Write-ColorOut "Path not found - aborting!" -ForegroundColor Red
        Start-Sound(0)
        Exit
    }
}

Start-Everything
