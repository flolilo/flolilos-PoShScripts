#requires -version 3

<#
    .SYNOPSIS
        Start both Outlook and OutlookGoogleCalendarSync
#>
param(
    [string]$Outlook    = "C:\Program Files (x86)\Microsoft Office\root\Office16\OUTLOOK.EXE",
    [string]$OGCS       = "D:\Downloads\OutlookGoogleCalendarSync\OutlookGoogleCalendarSync.exe"
)

# DEFINITION: Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding

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

Function Start-Everything(){
    param(
        [Parameter(Mandatory=$true)]
        $Outlook,
        [Parameter(Mandatory=$true)]
        $OGCS
    )

    if(@(Get-Process -ErrorAction SilentlyContinue -Name $($Outlook.BaseName)).count -eq 0){
        Write-ColorOut "$($Outlook.Name) not yet running - starting now..." -ForegroundColor Cyan
        try{
            Push-Location $Outlook.Directory
            Start-Process -FilePath $Outlook.FullName -Verbose
            Pop-Location
        }catch{
            Write-ColorOut "Starting `"$($Outlook.FullName)`" failed!" -ForegroundColor Red
        }
        Start-Sleep -Seconds 5
    }else{
        Write-ColorOut "$($Outlook.Name) already running." -ForegroundColor Yellow
    }

    if(@(Get-Process -ErrorAction SilentlyContinue -Name $($OGCS.BaseName)).count -eq 0){
        Write-ColorOut "$($OGCS.Name) yet not running - starting now..." -ForegroundColor Cyan
        try{
            Push-Location $OGCS.Directory
            Start-Process -FilePath $OGCS.FullName -Verbose
            Pop-Location
        }catch{
            Write-ColorOut "Starting `"$($OGCS.FullName)`" failed!" -ForegroundColor Red
        }
    }else{
        Write-ColorOut "$($OGCS.Name) already running." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 5
}

if($Outlook.Length -lt 5 -or (Test-Path -LiteralPath $Outlook -PathType Leaf) -eq $false){
    Write-ColorOut "$Outlook not found!" -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}elseif($OGCS.Length -lt 5 -or (Test-Path -LiteralPath $OGCS -PathType Leaf) -eq $false){
    Write-ColorOut "$OGCS not found!" -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}else{
    [array]$Outlook = Get-Item -LiteralPath $Outlook | ForEach-Object {
        [PSCustomObject]@{
            FullName = $_.FullName
            Name = $_.Name
            BaseName = $_.BaseName
            Directory = Split-Path -Path $_.FullName -Parent
        }
    }
    [array]$OGCS = Get-Item -LiteralPath $OGCS | ForEach-Object {
        [PSCustomObject]@{
            FullName = $_.FullName
            Name = $_.Name
            BaseName = $_.BaseName
            Directory = Split-Path -Path $_.FullName -Parent
        }
    }
    Start-Everything -Outlook $Outlook -OGCS $OGCS
}
