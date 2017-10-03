#requires -version 3

<#
    .SYNOPSIS
        Start both Outlook and OutlookGoogleCalendarSync
#>
param(
    [string]$outlook="C:\Program Files (x86)\Microsoft Office\root\Office16\OUTLOOK.EXE",
    [string]$OGCS="D:\Downloads\OutlookGoogleCalendarSync\OutlookGoogleCalendarSync.exe"
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

if(@(Get-Process -ErrorAction SilentlyContinue -Name outlook).count -eq 0){
    Write-ColorOut "Outlook not yet started - starting now..." -ForegroundColor Cyan
    Start-Process -FilePath $outlook -Verbose
    Start-Sleep -Seconds 5
}else{
    Write-ColorOut "Outlook already started." -ForegroundColor Yellow
}

if(@(Get-Process -ErrorAction SilentlyContinue -Name OutlookGoogleCalendarSync).count -eq 0){
    Write-ColorOut "OutlookGoogleCalendarSync yet not started - starting now..." -ForegroundColor Cyan
    Start-Process -FilePath $OGCS -Verbose
}else{
    Write-ColorOut "OutlookGoogleCalendarSync already started." -ForegroundColor Yellow
}
Start-Sleep -Seconds 5
