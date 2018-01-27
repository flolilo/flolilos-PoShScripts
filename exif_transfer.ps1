#requires -version 3

<#
    .SYNOPSIS
        Changes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.
    .DESCRIPTION
        Uses exiftool by Phil Harvey (https://sno.phy.queensu.ca/~phil/exiftool/)
    .NOTES
        Version:        1.0
        Author:         flolilo
        Creation Date:  2018-01-27

    .INPUTS
        exiftool.exe
        (optional) exif_tool_vars.json, formatted in UTF8 for copyright-values (if not provided via parameters).
    .OUTPUTS
        none.

    .PARAMETER InputPath
        Path where images should be searched and edited (default: current path of console).
    .PARAMETER ShowValues
        Show copyright-values before adding them.
    .PARAMETER Debug
        Add a bit of verbose information about variables.

    .EXAMPLE
        exif_tool -AddCopyright 1 -ArtistName "John Doe" -CopyrightText "2017, by John Doe." -Encoder "C:\exiftool.exe"
#>
param(
    [string]$InputPath =    "$((Get-Location).Path)",
    [int]$ShowValues =      0,
    [string]$Encoder =      "$($PSScriptRoot)\exiftool.exe",
    [int]$Debug =           0
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


# ==================================================================================================
# ==============================================================================
#    Defining specific functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Get user-values:
Function Start-Transfer(){
    Write-ColorOut "$(Get-Date -Format "yy.MM.dd - HH:mm")  -" -NoNewLine -ForegroundColor Gray
    Write-ColorOut "-  Transfering metadata..." -ForegroundColor Cyan

    [array]$original = @()
    [array]$jpg = @()
    [array]$files = @(Get-ChildItem -Path $script:InputPath -File | ForEach-Object {
        [PSCustomObject]@{
            BaseName = $_.BaseName
            FullName = $_.FullName
        }
    })

    [array]$files = @($files | Group-Object -Property BaseName | Where-Object {$_.Count -eq 2})

    for($i=0; $i -lt $files.Length; $i++){
            $original += @($files[$i].Group.FullName | Where-Object {$_ -notmatch ".jpg" -and $_ -notmatch ".jpeg"})
            $jpg += @($files[$i].Group.FullName | Where-Object {$_ -match ".jpg" -or $_ -match ".jpeg"})
    }

    for($i=0; $i -lt $original.Length; $i++){
        Write-ColorOut $original[$i] -ForegroundColor Gray
        Write-ColorOut $jpg[$i]
    }
    Write-ColorOut "`r`nContinue?"
    Pause

    for($i=0; $i -lt $original.Length; $i++){
        Write-Progress -Activity "Transfering metadata..." -Status "# $($i+1) / $($original.Length)" -PercentComplete $($($i + 1) * 100 / $($original.Length))
        Start-Process -FilePath $script:Encoder -ArgumentList " -tagsfromfile `"$($original[$i])`" -All:All -overwrite_original `"$($jpg[$i])`"" -Wait -NoNewWindow
    }
    Write-Progress -Activity "Transfering metadata..." -Status "Done!" -Completed
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-ColorOut "Welcome to flolilo's exif-tool!" -ForegroundColor DarkCyan -BackgroundColor Gray

    if((Test-Path -LiteralPath $script:InputPath -PathType Container) -eq $true){
        Start-Transfer
        Write-ColorOut "$(Get-Date -Format "yy.MM.dd - HH:mm")  -" -NoNewLine -ForegroundColor Gray
        Write-ColorOut "-  Done!" -ForegroundColor Green
        Start-Sound -Success 1
    }else{
        Write-ColorOut "Path not found - aborting!" -ForegroundColor Red
        Start-Sound -Success 0
        Start-Sleep -Seconds 5
        Exit
    }
}

Start-Everything
