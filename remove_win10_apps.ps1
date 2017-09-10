#requires -version 5

<#
    .SYNOPSIS
        This script will allow you to uninstall all Win10 Apps.
    .DESCRIPTION
        CREDIT: https://www.tenforums.com/tutorials/4689-uninstall-apps-windows-10-a.html#option3
        All app-names are taken from this website; also, the syntax is derived from theirs.
        Please be careful with using this tool!
    .NOTES
        Version:        1.0
        Creation Date:  2017-09-09
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT"-tags to find them.
#>

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# Suppressing Remove-AppxPackage's Write-Progress:
$ProgressPreference = 'SilentlyContinue'

[int]$deleteuselessonly = 1
[switch]$wantverbose = $true
[switch]$wantwhatif = $true

# Starting the script as admin and getting values:
if((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) -eq $false){
    Write-Host "This script will ask for admin-rights. It changes the standard-behavior when doubleclicking a *.ps1-file." -ForegroundColor Cyan
    Write-Host "Dieses Skript wird um Administrator-Rechte fragen. Es aendert das Verhalten bei Doppelklicks auf *.ps1-Dateien." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}else{
    [int]$deleteuselessonly = $(if((Read-Host "Delete useless apps only?") -eq 1){1}else{0})
    [switch]$wantverbose = $(if((Read-Host "Want some verbose? (To see what's happening)`t") -eq 1){$true}else{$false})
    [switch]$wantwhatif = $(if((Read-Host "Activate dry-running? (Only show what would happen, not actually doing anything)`t") -eq 1){$true}else{$false})
}   

# DEFINITION: Making Write-Host much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-Host
        
        .DESCRIPTION
            Using the [Console]-commands to make everything faster.

        .NOTES
            Date: 2017-09-08
        
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
        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")][string]$ForegroundColor=[Console]::ForegroundColor,
        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")][string]$BackgroundColor=[Console]::BackgroundColor,
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


# DEFINITION: Create an array with all apps:
Function Set-Apps(){
    [array]$Apps = (0..100) | ForEach-Object {
        [PSCustomObject]@{
            ClearName = "XYZ"
            AppName = "XYZ"
            Useless = 0
        }
    }

    [array]$ClearName = @()
    [array]$AppName = @()
    [array]$Useless = @()

    $ClearName += "3D Builder"
    $AppName += "*3dbuilder*"
    $Useless += 1

    $ClearName += "Alarms & Clock"
    $AppName += "*WindowsAlarms*"
    $Useless += 0

    $ClearName += "App Connector"
    $AppName += "*Appconnector*"
    $Useless += 0

    $ClearName += "Asphalt 8:Airborne"
    $AppName += "*Asphalt8Airborne*"
    $Useless += 1

    $ClearName += "Calculator"
    $AppName += "*WindowsCalculator*"
    $Useless += 0

    $ClearName += "Camera"
    $AppName += "*WindowsCamera*"
    $Useless += 0

    $ClearName += "Candy Crush Soda Saga"
    $AppName += "*CandyCrushSodaSaga*"
    $Useless += 1

    $ClearName += "Drawboard PDF"
    $AppName += "*DrawboardPDF*"
    $Useless += 1

    $ClearName += "Facebook"
    $AppName += "*Facebook*"
    $Useless += 1

    $ClearName += "Farmville 2: Country Escape"
    $AppName += "*FarmVille2CountryEscape*"
    $Useless += 1

    $ClearName += "Feedback Hub"
    $AppName += "*WindowsFeedbackHub*"
    $Useless += 1

    $ClearName += "Get Office"
    $AppName += "*officehub*"
    $Useless += 1

    $ClearName += "Get Skype"
    $AppName += "*Microsoft.SkypeApp*"
    $Useless += 1

    $ClearName += "Get Started / Tips (build 1703)"
    $AppName += "*Getstarted*"
    $Useless += 1

    $ClearName += "Groove Music"
    $AppName += "*ZuneMusic*"
    $Useless += 0

    $ClearName += "Mail and Calendar (Windows communication apps)"
    $AppName += "*windowscommunicationsapps*"
    $Useless += 0

    $ClearName += "Maps"
    $AppName += "*WindowsMaps*"
    $Useless += 0

    $ClearName += "Messaging + Skype"
    $AppName += "*Messaging*"
    $Useless += 1

    $ClearName += "Microsoft Solitaire Collection"
    $AppName += "*MicrosoftSolitaireCollection*"
    $Useless += 1

    $ClearName += "Microsoft Wallet"
    $AppName += "*Wallet*"
    $Useless += 0

    $ClearName += "Microsoft Wi-Fi"
    $AppName += "*ConnectivityStore*"
    $Useless += 0

    $ClearName += "MinecraftUWP"
    $AppName += "*MinecraftUWP*"
    $Useless += 1

    $ClearName += "Mixed Reality Portal"
    $AppName += "*HolographicFirstRun*"
    $Useless += 1

    $ClearName += "Money"
    $AppName += "*bingfinance*"
    $Useless += 1

    $ClearName += "Movies & TV"
    $AppName += "*ZuneVideo*"
    $Useless += 0

    $ClearName += "Netflix"
    $AppName += "*Netflix*"
    $Useless += 1

    $ClearName += "News"
    $AppName += "*BingNews*"
    $Useless += 1

    $ClearName += "OneNote"
    $AppName += "*OneNote*"
    $Useless += 1

    $ClearName += "Paid Wi-Fi & Cellular"
    $AppName += "*OneConnect*"
    $Useless += 1

    $ClearName += "Paint 3D"
    $AppName += "*MSPaint*"
    $Useless += 0

    $ClearName += "Pandora"
    $AppName += "*PandoraMediaInc*"
    $Useless += 1

    $ClearName += "People"
    $AppName += "*People*"
    $Useless += 0

    $ClearName += "Phone"
    $AppName += "*CommsPhone*"
    $Useless += 0

    $ClearName += "Phone Companion"
    $AppName += "*windowsphone*"
    $Useless += 0

    $ClearName += "Photos"
    $AppName += "*Photos*"
    $Useless += 0

    $ClearName += "Scan"
    $AppName += "*WindowsScan*"
    $Useless += 0

    $ClearName += "Skype Preview"
    $AppName += "*SkypeApp*"
    $Useless += 1

    $ClearName += "Sports"
    $AppName += "*bingsports*"
    $Useless += 1

    $ClearName += "Sticky Notes"
    $AppName += "*MicrosoftStickyNotes*"
    $Useless += 0

    $ClearName += "Store app"
    $AppName += "*WindowsStore*"
    # NOT RECOMMENDED, therefore -1 ( = super un-useless!)
    $Useless += -1

    $ClearName += "Sway"
    $AppName += "*Office.Sway*"
    $Useless += 1

    $ClearName += "Twitter"
    $AppName += "*Twitter*"
    $Useless += 1

    $ClearName += "View 3D Preview"
    $AppName += "*Microsoft3DViewer*"
    $Useless += 1

    $ClearName += "Voice Recorder"
    $AppName += "*soundrecorder*"
    $Useless += 0

    $ClearName += "Weather"
    $AppName += "*bingweather*"
    $Useless += 0

    $ClearName += "Xbox"
    $AppName += "*XboxApp*"
    $Useless += 0

    $ClearName += "Xbox One SmartGlass"
    $AppName += "*XboxOneSmartGlass*"
    $Useless += 0

    $ClearName += "Xbox Game Speech Window"
    $AppName += "*XboxSpeechToTextOverlay*"
    $Useless += 0
    
    for($i=0; $i -lt $ClearName.Length; $i++){
        $Apps[$i].ClearName = $ClearName[$i]
        $Apps[$i].AppName = $AppName[$i]
        $Apps[$i].Useless = $Useless[$i]
    }

    $Apps = $Apps | Sort-Object -Property ClearName,AppName -Unique
    $Apps | Out-Null
    return ($Apps | Where-Object {$_.ClearName -ne "XYZ" -and $_.AppName -ne "XYZ"})
}

[array]$AppArray = Set-Apps

<# DEFINITION: just for debug purposes:
    $AppArray | Format-Table -AutoSize
    Pause
#>

# DEFINITION: Removing apps:
foreach($i in $AppArray){
    if($deleteuselessonly -eq 0){
        [int]$check = -1
        while(($i.Useless -in (0..1) -and $check -notin (0..1)) -or ($i.Useless -eq -1 -and $check -notin @(0,2))){
            if($i.Useless -eq 0){
                Write-Host "Delete (potentially) usefull $($i.ClearName)?`t1 = yes, 0 = no.`t" -ForegroundColor Magenta -NoNewline
            }elseif($i.Useless -eq 1){
                Write-Host "Delete useless $($i.ClearName)?`t1 = yes, 0 = no.`t" -ForegroundColor DarkGreen -NoNewline
            }else{
                Write-Host "Delete $($i.ClearName)? NOT RECOMMENDED, as it will make it impossible to (re)install apps!`t2 = yes, 0 = no.`t" -ForegroundColor Red -NoNewline
            }
            [int]$check = Read-Host
        }
        if(($check -eq 1 -and $i.Useless -in (0..1)) -or ($check -eq 2 -and $i.Useless -eq -1)){
            try{
                Get-AppxPackage -AllUsers "$($i.AppName)" | Remove-AppxPackage -Verbose:$wantverbose -WhatIf:$wantwhatif
                Write-ColorOut "Removing $($i.ClearName) succeeded." -ForegroundColor DarkGreen
            }catch{
                Write-ColorOut "Removing $($i.ClearName) failed!" -ForegroundColor Magenta
            }
        }else{
            Write-ColorOut "Keeping $($i.ClearName)." -ForegroundColor Gray
        }
    }else{
        if($i.Useless -eq 1){
            try{
                Get-AppxPackage -AllUsers "$($i.AppName)" | Remove-AppxPackage -Verbose:$wantverbose -WhatIf:$wantwhatif
                Write-ColorOut "Removing $($i.ClearName) succeeded." -ForegroundColor DarkGreen
            }catch{
                Write-ColorOut "Removing $($i.ClearName) failed!" -ForegroundColor Magenta
            }
        }
    }
}

Write-ColorOut "Done!" -ForegroundColor Green
Pause
