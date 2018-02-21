#requires -version 5

<#
    .SYNOPSIS
        This script will allow you to uninstall all Win10 Apps.
    .DESCRIPTION
        CREDIT: https://www.tenforums.com/tutorials/4689-uninstall-apps-windows-10-a.html#option3
        All app-names are taken from this website; also, the syntax is derived from theirs.
        Please be careful with using this tool!
    .NOTES
        Version:        1.1
        Creation Date:  2017-11-29
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT"-tags to find them.
#>

# Get all error-outputs in English:
    [Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# Suppressing Remove-AppxPackage's Write-Progress:
    $ProgressPreference = 'SilentlyContinue'


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

# DEFINITION: Starting the script as admin and getting values:
Function Get-UserValues(){
    while($true){
        Write-ColorOut "Auto-delete certain apps? (2 means `"all except of the store`", 1 means `"only games and junk`", 0 means `"I want to decide on a per-app-basis.`")`t" -ForegroundColor Green -NoNewLine
        try{
            [int]$script:DeleteUselessOnly = Read-Host
            if($script:DeleteUselessOnly -in (0..2)){
                break
            }else{
                Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 4
            }
        }catch{
            Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 4
        }
    }
    while($true){
        Write-ColorOut "Want some verbose (to see what's happening)? (1 means `"yes`", 0 means `"no`".)`t" -ForegroundColor Gray -NoNewLine
        try{
            [int]$inter = Read-Host
            if($inter -in (0..1)){
                [switch]$script:WantVerbose = $(if($inter -eq 1){$true}else{$false})
                break
            }else{
                Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 4
            }
        }catch{
            Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 4
        }
    }
    while($true){
        Write-ColorOut "Only show what would happen without actually doing anything? (1 means `"yes`", 0 means `"no`".)`t" -ForegroundColor DarkGreen -NoNewLine
        try{
            [int]$inter = Read-Host
            if($inter -in (0..1)){
                [switch]$script:WantWhatIf = $(if($inter -eq 1){$true}else{$false})
                break
            }else{
                Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 4
            }
        }catch{
            Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 4
        }
    }

    if($script:DeleteUselessOnly -eq 0){
        Write-ColorOut "`r`nDelete:`t`tManually" -ForegroundColor DarkGreen
    }elseif($script:DeleteUselessOnly -eq 1){
        Write-ColorOut "`r`nDelete:`t`tJunk and useless stuff only" -ForegroundColor Yellow
    }
    elseif($script:DeleteUselessOnly -eq 2){
        Write-ColorOut "`r`nDelete:`t`tAll except from the store" -ForegroundColor Red
    }
    Write-ColorOut "Verbose:`t$script:WantVerbose" -ForegroundColor Gray
    if($script:WantWhatIf -eq 1){
        Write-ColorOut "What if:`t$script:WantWhatIf`r`n" -ForegroundColor DarkGreen
    }else{
        Write-ColorOut "What if:`t$script:WantWhatIf`r`n" -ForegroundColor Red
    }
    while($true){
        Write-Host "Is that okay? Proceed by entering 1:`t" -ForegroundColor Cyan -NoNewline
        if((Read-Host) -eq 1){
            break
        }else{
            continue
        }
    }
}

# DEFINITION: Create an array with all apps:
Function Set-Apps(){
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
    $Useless += 1

    $ClearName += "App Installer"
    $AppName += "*Microsoft.DesktopAppInstaller*"
    $Useless += 1

    $ClearName += "Asphalt 8:Airborne"
    $AppName += "*Asphalt8Airborne*"
    $Useless += 1

    $ClearName += "Calculator"
    $AppName += "*WindowsCalculator*"
    $Useless += 0

    $ClearName += "Calendar and Mail (Windows communication apps)"
    $AppName += "*windowscommunicationsapps*"
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

    $ClearName += "Fallout Shelter"
    $AppName += "*BethesdaSoftworks.FalloutShelter*"
    $Useless += 1

    $ClearName += "Farmville 2: Country Escape"
    $AppName += "*FarmVille2CountryEscape*"
    $Useless += 1

    $ClearName += "Feedback Hub"
    $AppName += "*WindowsFeedbackHub*"
    $Useless += 1

    $ClearName += "Get Help"
    $AppName += "*GetHelp*"
    $Useless += 1

    $ClearName += "Get Office"
    $AppName += "*officehub*"
    $Useless += 1

    $ClearName += "Get Skype"
    $AppName += "*SkypeApp*"
    $Useless += 1

    $ClearName += "Get Started / Tips (build 1703)"
    $AppName += "*Getstarted*"
    $Useless += 1

    $ClearName += "Groove Music"
    $AppName += "*ZuneMusic*"
    $Useless += 0

    $ClearName += "Maps"
    $AppName += "*WindowsMaps*"
    $Useless += 0

    $ClearName += "Messaging + Skype"
    $AppName += "*Messaging*"
    $Useless += 1

    $ClearName += "Microsoft Solitaire Collection"
    $AppName += "*SolitaireCollection*"
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

    <# TODO: won't work (Remove-AppxPackage : Deployment failed with HRESULT: 0x80073CFA)
        $ClearName += "Miracast"
        $AppName += "*MiracastView*"
        $Useless += 0
    #>

    <# TODO: won't work (Remove-AppxPackage : Deployment failed with HRESULT: 0x80073CFA)
        $ClearName += "Mixed Reality Portal"
        $AppName += "*HolographicFirstRun*"
        $Useless += 1
    #>

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
    $AppName += "*Microsoft.OneConnect*"
    $Useless += 1

    $ClearName += "Paint 3D"
    $AppName += "*MSPaint*"
    $Useless += 0

    $ClearName += "Pandora"
    $AppName += "*PandoraMediaInc*"
    $Useless += 1

    $ClearName += "People"
    $AppName += "*Microsoft.People*"
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

    $ClearName += "Royal Revolt 2"
    $AppName += "*flaregamesGmbH.RoyalRevolt2*"
    $Useless += 1

    $ClearName += "Scan"
    $AppName += "*WindowsScan*"
    $Useless += 0

    $ClearName += "Sketch Book"
    $AppName += "*AutodeskSketchBook*"
    $Useless += 1

    $ClearName += "Skype"
    $AppName += "*Microsoft.SkypeApp*"
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

    $ClearName += "Xbox Game Bar"
    $AppName += "*XboxGameOverlay*"
    $Useless += 0

    $ClearName += "Xbox Game Speech Window"
    $AppName += "*XboxSpeechToTextOverlay*"
    $Useless += 0

    $ClearName += "Xbox Identity Provider"
    $AppName += "*XboxIdentityProvider*"
    $Useless += 0

    $ClearName += "Xbox One SmartGlass"
    $AppName += "*XboxOneSmartGlass*"
    $Useless += 0


    [array]$Apps = (0..$ClearName.Length) | ForEach-Object {
        [PSCustomObject]@{
            ClearName = "XYZ"
            AppName = "XYZ"
            Useless = 0
        }
    }
    for($i=0; $i -lt $ClearName.Length; $i++){
        $Apps[$i].ClearName = $ClearName[$i]
        $Apps[$i].AppName = $AppName[$i]
        $Apps[$i].Useless = $Useless[$i]
    }


    $Apps = @($Apps | Sort-Object -Property ClearName,AppName -Unique)
    $Apps | Out-Null
    return @($Apps | Where-Object {$_.ClearName -ne "XYZ" -and $_.AppName -ne "XYZ"})
}

Function Start-Everything(){
    if((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) -eq $false){
        Write-ColorOut "This script will ask for admin-rights in a few seconds." -ForegroundColor Cyan
        Write-ColorOut "Dieses Skript wird gleich um Administrator-Rechte fragen." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        Exit
    }else{
        Get-UserValues
        [array]$AppArray = @(Set-Apps)
    
        <# DEFINITION: just for debug purposes:
            $AppArray | Format-Table -AutoSize
            $AppArray.Length
            Pause
        #>
    
        # DEFINITION: Removing apps:
        foreach($i in $AppArray){
            if($script:DeleteUselessOnly -eq 0){
                while($true){
                    if($i.Useless -eq 0){
                        Write-Host "Delete (potentially) usefull $($i.ClearName)?`t1 = yes, 0 = no.`t" -ForegroundColor Magenta -NoNewline
                    }elseif($i.Useless -eq 1){
                        Write-Host "Delete useless $($i.ClearName)?`t1 = yes, 0 = no.`t" -ForegroundColor DarkGreen -NoNewline
                    }else{
                        Write-Host "Delete $($i.ClearName)? NOT RECOMMENDED, as it will make it impossible to (re)install apps!`t2 = yes, 0 = no.`t" -ForegroundColor Red -NoNewline
                    }
                    [int]$check = Read-Host
                    if(($i.Useless -in (0..1) -and $check -in (0..1)) -or ($i.Useless -eq -1 -and $check -in (0..2))){
                        break
                    }else{
                        Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 8
                        continue
                    }
                }
                if(($check -eq 1 -and $i.Useless -in (0..1)) -or ($check -eq 2 -and $i.Useless -ne -1)){
                    try{
                        Get-AppxPackage -AllUsers "$($i.AppName)" | Remove-AppxPackage -Verbose:$script:WantVerbose -WhatIf:$script:WantWhatIf -ErrorAction Stop
                        Write-ColorOut "Removing $($i.ClearName) succeeded." -ForegroundColor DarkGreen -Indentation 4
                    }catch{
                        Write-ColorOut "Removing $($i.ClearName) failed!" -ForegroundColor Magenta -Indentation 4
                        Start-Sound -Success 0
                    }
                }else{
                    Write-ColorOut "Keeping $($i.ClearName)." -ForegroundColor Gray -Indentation 4
                }
            }elseif(($script:DeleteUselessOnly -eq 1 -and $i.Useless -eq 1) -or ($script:DeleteUselessOnly -eq 2 -and $i.Useless -in (0..1))){
                try{
                    Get-AppxPackage -AllUsers "$($i.AppName)" | Remove-AppxPackage -AllUsers -Verbose:$script:WantVerbose -WhatIf:$script:WantWhatIf -ErrorAction Stop
                    Write-ColorOut "Removing $($i.ClearName) succeeded." -ForegroundColor DarkGreen -Indentation 4
                }catch{
                    Write-ColorOut "Removing $($i.ClearName) failed!" -ForegroundColor Magenta -Indentation 4
                    Start-Sound -Success 0
                }
            }else{
                Write-ColorOut "Keeping $($i.ClearName)." -ForegroundColor Gray -Indentation 4
            }
        }
        Write-ColorOut "Done!" -ForegroundColor Green
        Start-Sound -Success 1
        Pause
    }
}
Start-Everything
