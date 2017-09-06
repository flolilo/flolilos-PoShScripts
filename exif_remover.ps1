#requires -version 3

<#
    .SYNOPSIS
        Removes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.

    .DESCRIPTION
        Uses exiftool.

    .INPUTS
        exiftool.exe

    .OUTPUTS
        none.

    .NOTES
        Version:        1.0
        Author:         flolilo
        Creation Date:  2017-09-06

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
    [string]$artist_name = "Unknown",
    [string]$copyright_text = "No copyright information added",
    [string]$encoder = "$($PSScriptRoot)\exiftool.exe",
    [string]$path = (Get-Location).Path
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

if((Test-Path -LiteralPath $encoder -PathType Leaf) -eq $false){
    Write-ColorOut "Exiftool not found - aborting!" -ForegroundColor Red
    Exit
}

if((Test-Path -LiteralPath $path -PathType Container) -eq $true){
    [array]$files = @()
    $files = Get-ChildItem -LiteralPath $path -Filter *.jpg
}else{
    Write-ColorOut "Path not found - aborting!" -ForegroundColor Red
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
