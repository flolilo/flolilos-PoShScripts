#requires -version 3

<#
    .SYNOPSIS
        Prevents idle-standby while CPU is working or while specified processes are running.

    .DESCRIPTION
        Will simulate F15-key-press to prevent computer from entering standby. 

    .NOTES
        Version:        1.4
        Creation Date:  25.7.2017
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT"-tags to find them.

    .PARAMETER fileToCheck
        String. Path to file of script that uses -fileModeEnable. 
    .PARAMETER fileModeEnable
        Integer. Value of 1 enables file-mode. Only recommended for use with other sripts.
    .PARAMETER mode
        String. Valid options:
            "Process"   - Script will close after certain process(es) are finished.
            "CPU"       - Script will close when certain CPU-usage-percentage is no longer topped.
            "None"      - Only valid if -fileModeEnable = 1. Sript will close after -fileToCheck's value is 1.
    .PARAMETER userProcessCount
        Integer. Only valid when -mode = "process". Value specifies how many processes the script will look for.
    .PARAMETER userProcess
        Array. Specifies processes that the user wants the script to watch for.
    .PARAMETER userCPUlimit
        Integer. Specifies threshold of CPU-usage that the script should watch for.
    .PARAMETER timeBase
        Integer. Value of time (in seconds) that has to pass between to iterations of the script - different steps of the script will use from $timeBase/2 to $timeBase/10 as their values.
    .PARAMETER counterMax
        Integer. Maximum time of iterations between criteria for closing the script are met and the atual closing of the script.
    .PARAMETER shutdown
        Integer. Value of 1 will initiate shutdown of computer after finishing the script. Value of -1 (default) will ask if shutdown should be initiated or not.

    .INPUTS
        -fileToCheck's file if -fileModeEnable is enabled.
    .OUTPUTS
        None.

    .EXAMPLE
        Run forever:
        preventsleep.ps1 -mode "CPU" -userCPUlimit -1 -shutdown 0
    .EXAMPLE
        Check if robocopy is runnning and shut down afterwards:
        preventsleep.ps1 -mode "process" -userProcessCount 1 -userProcess "robocopy" -shutdown 1
#>
param(
    [string]$fileToCheck = "$PSScriptRoot\fertig.txt",
    [ValidateRange(0,1)][int]$fileModeEnable = 0,
    [ValidateSet("process","specify","cpu","none")][string]$mode = "specify",
    [ValidateRange(-1,1)][int]$userProcessCount = -1,
    [array]$userProcess = @(),
    [ValidateRange(-1,99)][int]$userCPUlimit = -10,
    [ValidateRange(10,3000)][int]$timeBase = 300,
    [ValidateRange(1,100)][int]$counterMax = 10,
    [ValidateRange(-1,1)][int]$shutdown = -1
)

#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding

# DEFINITION: Making Write-ColorOut much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-ColorOut
        
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
        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","Darkgray","Gray","DarkYellow","White","DarkMagenta")][string]$ForegroundColor=[Console]::ForegroundColor,
        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","Darkgray","Gray","DarkYellow","White","DarkMagenta")][string]$BackgroundColor=[Console]::BackgroundColor,
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

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'


# For button-emulation:
$MyShell = New-Object -com "Wscript.Shell"

# DEFINITION: Get Average CPU-usage:
Function Get-ComputerStats(){
    [array]$cpu = @()
    for($i = 0; $i -lt 3; $i++){
        $cpu += Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | ForEach-Object {$_.Average}
        Start-Sleep -Seconds 1
    }
    return ([math]::ceiling(($cpu[0] + $cpu[1] + $cpu[2]) / 3))
}

Write-ColorOut "flolilo's Preventsleep-Script v1.4 /" -ForegroundColor Cyan -NoNewline
Write-ColorOut "/ flolilos Schlaf-Verhinder-Skript v1.4" -ForegroundColor Yellow
Write-ColorOut "This script prevents the standby-mode while specified processes are running. /" -ForegroundColor Cyan -NoNewline
Write-ColorOut "/ Dieses Skript verhindert, dass der Computer waehrend der Ausfuehrung der angegebenen Prozesse in den Standby wechselt." -ForegroundColor Yellow
Write-ColorOut "PLEASE DON'T CLOSE THIS WINDOW! // BITTE FENSTER NICHT SCHLIESSEN!`r`n" -ForegroundColor Red -BackgroundColor White

# DEFINITION: After direct start:
if($mode -eq "specify"){
    while($true){
        Write-ColorOut "Which mode? `"CPU`" for CPU-Usage or `"process`" for process-specific. (both w/o quotes): /" -NoNewline
        Write-ColorOut "/ Welcher Modus? `"CPU`" fuer CPU-Auslastung oder `"process`" fuer Prozess-Ueberwachung. (beides ohne Anfuerhungszeichen):" -ForegroundColor DarkGray
        [string]$mode = Read-Host
        if($mode -eq "CPU" -or $mode -eq "process"){
            break
        }else{
            Write-ColorOut "Invalid choice, please try again. // Ungueltige Angabe, bitte erneut versuchen." -ForegroundColor Magenta
            continue
        }
    }
}
if($mode -eq "cpu"){
    if($userCPUlimit -eq -10){
        while($true){
            Write-ColorOut "Enter the CPU-threshold in %. (enter w/o %-sign) - Recommendation: 90%, -1% to run script forever: /" -NoNewline
            Write-ColorOut "/ Grenzwert der CPU-Auslastung in % angeben? (Angabe ohne %-Zeichen) Empfehlung: 90%, -1% falls Skript ewig laufen soll:" -ForegroundColor DarkGray
            [int]$userCPUlimit = Read-Host
            if($userCPUlimit -in (-1..99)){
                break
            }else{
                Write-ColorOut "Invalid choice, please try again. // Ungueltige Angabe, bitte erneut versuchen." -ForegroundColor Magenta
                continue
            }
        }
    }
}
if($mode -eq "process"){
    if($userProcessCount -eq -1){
        while($true){
            Write-ColorOut "How many Processes? /" -NoNewLine
            Write-ColorOut "/ Wieviele Prozesse?" -ForegroundColor DarkGray
            [int]$userProcessCount = Read-Host
            if($userProcessCount -in (1..100)){
                break
            }else{
                Write-ColorOut "Invalid choice, please try again. // Ungueltige Angabe, bitte erneut versuchen." -ForegroundColor Magenta
                continue
            }
        }
    }
    if($userProcess.Length -eq 0){
        for($i = 0; $i -lt $userProcessCount; $i++){
            Write-ColorOut "Please specify name of process No. $($i + 1): /" -NoNewline
            Write-ColorOut "/ Bitte Namen von Prozess Nr. $($i + 1) eingeben:`t" -ForegroundColor DarkGray -NoNewline
            [array]$userProcess += Read-Host 
        }
    }
    if("powershell" -in $userProcess){
        [int]$compensation = 1
    }else{
        [int]$compensation = 0
    }
}
if($shutdown -eq -1){
    while($true){
        Write-ColorOut "Shutdown when done? `"1`" for yes, `"0`" for no. /" -NoNewline
        Write-ColorOut "/ Nach Abschluss herunterfahren? `"1`" fuer Ja, `"0`" fuer Nein." -ForegroundColor DarkGray
        [int]$shutdown = Read-Host
            if($shutdown -in (0..1)){
            break
        }else{
            Write-ColorOut "Invalid choice, please try again. // Ungueltige Angabe, bitte erneut versuchen." -ForegroundColor Magenta
            continue
        }
    }
}
if($mode -eq "none" -and $fileModeEnable -eq 0){
    Write-ColorOut "`r`nInvalid choice: if -mode is `"none`", then -fileModeEnable must be set to 1. ABORTING. // Ungueltige Auswahl: wenn -mode `"none`" ist, muss -fileModeEnable 1 sein." -ForegroundColor Red
    Pause
    Exit
}

# DEFINITION: Start it:
Write-ColorOut " "
$counter = 0
while($counter -lt $counterMax){
    if($fileModeEnable -eq 1){
        if((Test-Path -Path $fileToCheck) -eq $true){
            $fileSaysDone = Get-Content -Path "$fileToCheck" -ErrorAction SilentlyContinue
            if($fileSaysDone -eq 0){
                Write-ColorOut "$(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -NoNewline
                Write-ColorOut " - File-based process unfinished, sleeping for $($timeBase / 10) seconds. // Datei-basierter Prozess noch nicht fertig, schlafe $($timeBase / 10) Sekunden." -ForegroundColor Yellow
            }else{
                Write-ColorOut "$(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -NoNewline
                Write-ColorOut " - File-based process done! Sleeping for $($timeBase / 10) seconds. // Datei-basierter Prozess fertig! Schlafe fuer $($timeBase / 10) Sekunden." -ForegroundColor Green
                $fileModeEnable = 0
            }
        }Else{
            $fileModeEnable = 0
            Write-ColorOut "File `"$fileToCheck`" wasn't found. Changing into fileless mode. // Datei `"$fileToCheck`" konnte nicht gefunden werden. Wechsle in dateilosen Modus." -ForegroundColor DarkRed
        }
        $MyShell.sendkeys("{F15}")
        Start-Sleep -Seconds $($timeBase / 10)
    }
    if($fileModeEnable -eq 0 -and $mode -eq "process"){
        $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name $userProcess).count - $compensation
        if($activeProcessCounter -ne 0){
            Write-ColorOut "$(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -NoNewline
            Write-ColorOut " - Process(es) `"$userProcess`" not yet done, sleeping for $timeBase seconds. // Prozess(e) `"$userProcess`" noch nicht fertig, schlafe $timeBase Sekunden." -ForegroundColor Yellow
            $counter = 0
            $MyShell.sendkeys("{F15}")
            Start-Sleep -Seconds $($timeBase)
        }Else{
            Write-ColorOut "$(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -NoNewline
            Write-ColorOut " - Process(es) `"$userProcess`" done, sleeping for $($timeBase / 2) seconds. // Prozess(e) `"$userProcess`" fertig, schlafe $($timeBase / 2) Sekunden." -ForegroundColor Green
            Write-ColorOut "$counter/$counterMax Passes without any activity. // $counter/$counterMax Durchgaenge ohne Aktivitaet." -ForegroundColor Green
            $counter ++
            $MyShell.sendkeys("{F15}")
            Start-Sleep -Seconds $($timeBase / 2)
        }
    }
    if($fileModeEnable -eq 0 -and $mode -eq "CPU"){
        $CPUstats = Get-ComputerStats
        if($CPUstats -gt $userCPUlimit){
            Write-ColorOut "$(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -NoNewline
            Write-ColorOut " - CPU usage is $($CPUstats)% = above $($userCPUlimit)%, sleeping for $timeBase seconds. // CPU-Auslastung $($CPUstats)% = ueber $($userCPUlimit)%, schlafe $timeBase Sekunden." -ForegroundColor Yellow
            $counter = 0
            $MyShell.sendkeys("{F15}")
            Start-Sleep -Seconds $($timeBase)
        }else{
            Write-ColorOut "$(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -NoNewline
            Write-ColorOut " - CPU usage $($CPUstats)% = below $($userCPUlimit)%, sleeping for $($timeBase / 2) seconds. // CPU-Auslastung $($CPUstats)% = unter $($userCPUlimit)%, schlafe $($timeBase / 2) Sekunden." -ForegroundColor Green
            $counter++
            $MyShell.sendkeys("{F15}")
            Start-Sleep -Seconds $($timeBase / 2)
        }
    }
    if($mode -eq "none"){
        Write-ColorOut "Mode `"none`" selected, program therefore finished. // Modus `"none`" gewaehlt, Programm daher fertig." -ForegroundColor Cyan
        $counter = $counterMax
        break
    }
}

Write-ColorOut "`r`n$(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -NoNewline
Write-ColorOut " - Done! // Fertig!" -ForegroundColor Green

if((Test-Path -Path "$fileToCheck") -eq $true){
    Remove-Item -Path "$fileToCheck" -Force -Verbose
}
if($shutdown -eq 1){
    Write-ColorOut "Shutting down... // Herunterfahren..." -ForegroundColor Red
    Start-Sleep -Seconds 10
    Stop-Computer
}
