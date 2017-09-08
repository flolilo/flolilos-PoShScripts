#requires -version 3

<#
    .SYNOPSIS
        Removes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.

    .DESCRIPTION
        Uses exiftool by Phil Harvey (https://sno.phy.queensu.ca/~phil/exiftool/)

    .INPUTS
        exiftool.exe
        exif_remover_vars.txt, formatted in UTF8 for copyright-values (if not provided via parameters).

    .OUTPUTS
        none.

    .NOTES
        Version:        1.1
        Author:         flolilo
        Creation Date:  2017-09-08

    .PARAMETER add_copyright
        Enables or disables writing of copyright-information (specified with -artist_name and -copyright_text).
    .PARAMETER artist_name
        Name of artist.
    .PARAMETER copyright_text
        Copyright-information you want to add.
    .PARAMETER encoder
        Path to exiftool.exe
    .PARAMETER path
        Path where images should be searched and edited (default: current path of console).

    .EXAMPLE
        exit_remover -add_copyright 1 -artist_name "John Doe" -copyright_text "2017, by John Doe. -encoder "C:\exiftool.exe"
#>

param(
    [int]$add_copyright = 0,
    [string]$artist_name = "",
    [string]$copyright_text = "",
    [string]$encoder = "$($PSScriptRoot)\exiftool.exe",
    [string]$path = (Get-Location).Path,
    [int]$showvalues = 0
)

if($add_copyright -eq 1 -and ($artist_name.Length -eq 0 -or $copyright_text.Length -eq 0)){
    if((Test-Path -LiteralPath "$($PSScriptRoot)\exif_remover_vars.txt" -PathType Leaf)){
        $temp = Get-Content -LiteralPath "$($PSScriptRoot)\exif_remover_vars.txt" -Raw -Encoding UTF8 | ConvertFrom-StringData
        $artist_name = $temp.artist_name
        $copyright_text = $temp.copyright_text
    }else{
        Write-Host "ERROR - no copyright values and no $($PSScriptRoot)\exif_remover_vars.txt!" -ForegroundColor Red
        Start-Sleep -Seconds 5
        Exit
    }
}

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

if($showvalues -ne 0){
    Write-ColorOut $artist_name -ForegroundColor Gray
    Write-ColorOut $copyright_text -ForegroundColor DarkGray
    Pause
    Exit
}

if((Test-Path -LiteralPath $encoder -PathType Leaf) -eq $false){
    if((Test-Path -LiteralPath "$($PSScriptRoot)\exiftool.exe" -PathType Leaf) -eq $false){
        Write-ColorOut "Exiftool not found - aborting!" -ForegroundColor Red
        Start-Sound(0)
        Exit
    }else{
        $encoder = "$($PSScriptRoot)\exiftool.exe"
    }
}

if((Test-Path -LiteralPath $path -PathType Container) -eq $true){
    [array]$files = @()
    $files = Get-ChildItem -LiteralPath $path -Filter *.jpg
}else{
    Write-ColorOut "Path not found - aborting!" -ForegroundColor Red
    Start-Sound(0)
    Exit
}

Write-ColorOut "Deleting EXIFs..." -ForegroundColor Yellow
for($i=0; $i -lt $files.Length; $i++){
    while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -ge 8){
        Start-Sleep -Milliseconds 25
    }
    Write-ColorOut $files[$i].FullName -ForegroundColor Gray
    Start-Process -FilePath $encoder -ArgumentList " -IPTC:All= -XMP:All= -EXIF:All= -photoshop:All= -adobe:all= -overwrite_original `"$($files[$i].FullName)`"" -WindowStyle Hidden
}
while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -gt 0){
    Start-Sleep -Milliseconds 25
}
Start-Sleep -Milliseconds 250

if($add_copyright -eq 1){
    Write-ColorOut "Adding Copyright..." -ForegroundColor Yellow
    for($i=0; $i -lt $files.Length; $i++){
        while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -ge 8){
            Start-Sleep -Milliseconds 25
        }
        Write-ColorOut $files[$i].FullName -ForegroundColor Gray
        Start-Process -FilePath $encoder -ArgumentList " -artist=`"$artist_name`" -copyright=`"$copyright_text`" -overwrite_original `"$($files[$i].FullName)`"" -WindowStyle Hidden
    }
}
while((Get-Process -ErrorAction SilentlyContinue -Name "exiftool").count -gt 0){
    Start-Sleep -Milliseconds 25
}
Start-Sleep -Milliseconds 250

Write-ColorOut "Done!" -ForegroundColor Green
Start-Sound(1)
