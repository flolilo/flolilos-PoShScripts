#requires -version 3

<#
    .SYNOPSIS
        Kopiert Video-Dateien von SD-Karte auf Festpatte und kodiert sie dann in eine vierfach-Ansicht.
    .DESCRIPTION
        Benutzt FFmpeg zum Kodieren und Robocopy / Xcopy zum Kopieren.
    .NOTES
        Version:        3.0
        Autor:          flolilo
        Datum:          25.7.2017
        Rechtliches:    Diese Software ist gratis und darf jederzeit weiterwerwendet und -entwickelt werden (bitte mit Namensnennung). Es wird keine Haftung fuer die Funktion des Skripts - oder durch es entstehende Schaeden in Form von Datenverlust o.Ae. - uebernommen. Der Grossteil des Skripts wurde von mir selbst geschrieben (oder von Quellen aus dem Internet abgeleitet und stark modifiziert). Teile, die Code Dritter enthalten, sind mit dem "#CREDIT"-Tag ausgewiesen.
    .PARAMETER encoder
        Pfad zum Encoder, z.B. "C:\FFMPEG\binaries\ffmpeg.exe"
    .PARAMETER CDrive
        Beliebiger Pfad auf der C-Festplatte, z.B. "C:\FFMPEG"
    .PARAMETER debug
        Wert 1 fuer Extra-Pausen zwischen einzenen Schritten und Pause am Ende.
    .PARAMETER stayawake
        Wert 1 um Standby waehrend der Ausfuehrung zu verhindern.
    .INPUTS
        Keine.
    .OUTPUTS
        TODO: Dateien die ausgegeben werden?
    .EXAMPLE
        security-cam_gui.ps1
#>
param(
    [string]$Encoder = "C:\FFMPEG\binaries\ffmpeg.exe",
    [string]$CDrive = "C:\FFMPEG",
    [string]$sd_karte = "",
    [string]$ausgabe = "",
    [int]$modus = 0,
    [int]$hardware = 0,
    [int]$multithread = 1,
    [int]$stayawake = 1,
    [int]$herunterfahren = 0,
    [string]$GUI_Direct = "GUI",
    [int]$debug = 0
)

#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

# DEFINITION: Making Write-ColorOut much, much faster:
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

# Set standard ErrorAction to 'Stop':
if($debug -eq 0){
    # Usual ErrorAction: Stop: https://stackoverflow.com/a/21260623/8013879
    $PSDefaultParameterValues = @{}
    $PSDefaultParameterValues += @{'*:ErrorAction' = 'Stop'}
    $ErrorActionPreference = 'Stop'
}

# If you want to see the variables (buttons, checkboxes, ...) the GUI has to offer, set this to 1:
[int]$getWPF = 0


# ==================================================================================================
# ==============================================================================
#   Defining Functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Pause the programme if debug-var is active. Also, enable measuring times per command with -debug 3.
Function Invoke-Pause(){
    param($tottime=0.0)

    if($script:debug -eq 3 -and $tottime -ne 0.0){
        Write-ColorOut "Used time for process:`t$tottime`r`n" -ForegroundColor Magenta
    }
    if($script:debug -ge 2){
        if($tottime -ne 0.0){
            $script:timer.Stop()
        }
        Pause
        if($tottime -ne 0.0){
            $script:timer.Start()
        }
    }
}

# DEFINITION: Exit the program (and close all windows) + option to pause before exiting.
Function Invoke-Close(){
    if($script:GUI_CLI_Direct -eq "GUI"){
        $script:Form.Close()
    }
    Write-ColorOut "Exiting - This could take some seconds. Please do not close window!" -ForegroundColor Magenta
    Get-RSJob | Stop-RSJob
    Start-Sleep -Milliseconds 5
    Get-RSJob | Remove-RSJob
    if($script:debug -ne 0){
        Pause
    }
    Exit
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

# DEFINITION: "Select"-Window for buttons to choose a path.
Function Get-Folder($InOut){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $folderdialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderdialog.rootfolder = "MyComputer"
    if($folderdialog.ShowDialog() -eq "OK"){
        if($InOut -eq "input"){
            $script:WPFtextBoxInput.Text = $folderdialog.SelectedPath
        }
        if($InOut -eq "output"){
            $script:WPFtextBoxOutput.Text = $folderdialog.SelectedPath
        }
    }
}


#                 $InPath  $OutPath  $userMethode
Function Flo-Test($FloTestIn, $FloTestOut, $FloTestMode){
    Write-ColorOut "Bitte noch kurz hier bleiben, Skript überprüft Verzeichnis-Eingabe..." -ForegroundColor Cyan
    if($FloTestMode -eq 0){
        $eingangsordner = Test-Path -LiteralPath $FloTestIn -pathType container
        if($eingangsordner -eq $true){
            Set-Location $FloTestIn
            #Set-Location ..
            [String]$movieordner = (Resolve-Path .\).Path
            # $movieordner = (Get-ChildItem -Directory -Filter 'Movies').count
            if($movieordner -notlike '*Movies'){
                Write-ColorOut "Eingans-Ordner enthält keinen Ordner namens `"Movies`". Sicher, dass die Auswahl stimmt?" -ForegroundColor Red
                [int]$bestaetigungin = Read-Host "Taste `"1`" für `"Ja`", andere Ziffer für `"Nein`". Bestätigen mit Enter"
                if($bestaetigungin -eq 1){
                    $testinvar = $true
                }Else{
                    $testinvar = $false
                }
            }Else{
                $testinvar = $true
            }
        }Else{
            Write-ColorOut "Eingangs-Ordner nicht gefunden!" -ForegroundColor Red
            $testinvar = $false
        }
        if($testinvar -eq $true){
            $ausgangsordner = Test-Path -LiteralPath $FloTestOut -pathType container
                if($ausgangsordner -eq $true){
                $movieordner = (Get-ChildItem -LiteralPath $FloTestOut -Recurse -Exclude *_quad.mkv).count
                $testprogresstestA = Test-Path -Path $FloTestOut\progress_burnin_iteration.txt
                $testprogresstestB = Test-Path -Path $FloTestOut\progress_concat_iteration.txt
                $testprogresstestC = Test-Path -Path $FloTestOut\progress_quad_iteration.txt
                if($movieordner -ne 0){
                    if($testprogresstestA -eq $false -and $testprogresstestB -eq $false -and $testprogresstestC -eq $false){
                        Write-ColorOut "Ausgangs-Ordner enthält bereits Dateien. Das kann zu unvorhergesehenem Verhalten des Programs führen." -ForegroundColor Red
                        Write-ColorOut "Es wird empfohlen, alle Ordner und/oder Dateien im Pfad `"$FloTestOut`" an eine andere Stelle zu kopieren und erst dann fortzufahren, oder einen anderen Ausgabeordner zu wählen." -ForegroundColor Red
                    }Else{
                        Write-ColorOut "Zuvor abgebrochene Sitzung erkannt." -ForegroundColor Red
                        Write-ColorOut "Bitte einfach mit `"Nein`" zum Hauptfenster zurückkehren und von dort aus mit der Option `"Kodieren`" erneut beginnen." -ForegroundColor Red
                        Write-ColorOut " "
                    }
                    Write-ColorOut "Mit dem Kopieren fortfahren?" -ForegroundColor Yellow
                    [int]$bestaetigungout = Read-Host "Taste `"1`" für `"Ja`", andere Ziffer für `"Nein`". Bestätigen mit Enter"
                    if($bestaetigungout -eq 1){
                        $testoutvar = $true
                    }Else{
                        $testoutvar = $false
                    }
                }Else{
                    $testoutvar = $true
                }
            }Else{
                Write-ColorOut "Ausgangs-Ordner nicht gefunden!" -ForegroundColor Red
                $testoutvar = $false
            }
        }
        if($testinvar -eq $true -and $testoutvar -eq $true){
            return $true
        }Else{
            return $false
        }
    }Else{
        return $true
    }
}

#                 $InPath  $userOutput
Function Flo-Copy($FloCopyIn, $FloCopyOut){
	Write-ColorOut "Kopiere..." -ForegroundColor Yellow
    start-process robocopy.exe -ArgumentList "`"$FloCopyIn`" `"$FloCopyOut`" *.mp4 /S /V /R:100 /W:10 /MT:8" -Wait -NoNewWindow
	Write-ColorOut "Kopieren beendet!" -ForegroundColor Yellow
    Write-ColorOut " "
    Start-Sleep -Seconds 10
}

#                     $userOutput
Function Flo-Umbenenn($FloUmbenennOut){
	Write-ColorOut "Starte Umbenennung der Ordner und Dateien..."  -ForegroundColor Yellow
    Set-Location $FloUmbenennOut
	$unterordner = @(Get-ChildItem -Directory | ForEach-Object {$_.BaseName})
	for($i=0; $i -lt $unterordner.Length; $i++){
        Set-Location $FloUmbenennOut\$($unterordner[$i])
        $namenszeug = @(Get-ChildItem *.mp4 | ForEach-Object {$_.LastWriteTime.ToString("yyyy-MM-dd")})
        Set-Location $FloUmbenennOut
        $bla = $namenszeug[0]
        Rename-Item -path ".\$($unterordner[$i])" -newname "$($namenszeug[0])" -ErrorAction SilentlyContinue
		}
    Set-Location $FloUmbenennOut
    for($i=1; $i -le 4; $i++){
        Get-ChildItem *-$($i).mp4 -Recurse | Rename-Item -newname {"cam$($i)_" + $_.LastWriteTime.toString("HH-mm-ss") + ".mp4"}
    }
    Write-ColorOut "Ummbenennung fertig." -ForegroundColor Yellow
    Write-ColorOut " "
}

#                           $CDrive            $Encoder                   $OutPath            $multithread
Function Flo-KodiererBurnin($FloKodiererBurninPath, $FloKodiererBurninEncoder, $FloKodiererBurninOut, $FloKodiererBurninMultithread){
    Set-Location $FloKodiererBurninOut
    $progresstestA = Test-Path -Path $FloKodiererBurninOut\progress_burnin_full.txt
    $progresstestB = Test-Path -Path $FloKodiererBurninOut\progress_burnin_base.txt
    $progresstestC = Test-Path -Path $FloKodiererBurninOut\progress_burnin_iteration.txt
    $progresstestD = Test-Path -Path $FloKodiererBurninOut\progress_burnin_dir.txt
    if($progresstestA -eq $false -or $progresstestB -eq $false -or $progresstestC -eq $false -or $progresstestD -eq $false){
        $dateien = @(Get-ChildItem *.mp4 -Recurse)
        $dateien_dir =@(ForEach-Object {$dateien.DirectoryName})
        $dateinamen = @(ForEach-Object {$dateien.BaseName})
        $dateien = @(ForEach-Object {$dateien.FullName})
        $iteration = 0
        Out-File -FilePath $FloKodiererBurninOut\progress_burnin_full.txt -InputObject $dateien -Encoding utf8
        Out-File -FilePath $FloKodiererBurninOut\progress_burnin_base.txt -InputObject $dateinamen -Encoding utf8
        Out-File -FilePath $FloKodiererBurninOut\progress_burnin_dir.txt -InputObject $dateien_dir -Encoding utf8
        Out-File -FilePath $FloKodiererBurninOut\progress_burnin_iteration.txt -InputObject $iteration -Encoding utf8
    }Else{
        $readerA = [System.IO.File]::OpenText("$FloKodiererBurninOut\progress_burnin_full.txt")
        while($null -ne ($lineA = $readerA.ReadLine())) {
            [Array]$dateien += $lineA
        }
        $readerA.Close()
        $readerB = [System.IO.File]::OpenText("$FloKodiererBurninOut\progress_burnin_base.txt")
        while($null -ne ($lineB = $readerB.ReadLine())) {
            [Array]$dateinamen += $lineB
        }
        $readerB.Close()
        $readerC = [System.IO.File]::OpenText("$FloKodiererBurninOut\progress_burnin_iteration.txt")
        while($null -ne ($lineC = $readerC.ReadLine())) {
            [int]$iteration = $lineC
            if($iteration -lt 0){
                $iteration = 0
            }
        }
        $readerC.Close()
        $readerD = [System.IO.File]::OpenText("$FloKodiererBurninOut\progress_burnin_dir.txt")
        while($null -ne ($lineD = $readerD.ReadLine())) {
            [Array]$dateien_dir += $lineD
        }
        $readerD.Close()
        Write-ColorOut "Text-Dateien gefunden - setze Arbeit fort bei Datei Nr. $($iteration + 1) von $($dateien.Length)" -ForegroundColor Green
    }
	Write-ColorOut "Starte Burn-In-Kodierung der Dateinamen in Video..."  -ForegroundColor Yellow
    Write-ColorOut "Diese kann jederzeit unterbrochen und später wiederaufgenommen werden. Mit `"Strg`" + `"C`" unterbrechen, PC danach aber MINDESTENS EINE MINUTE LANG FERTIG RECHNEN LASSEN, d.h. nicht in Standby wechseln oder ausschalten!" -ForegroundColor Cyan
	Set-Location $FloKodiererBurninPath
    $anfang_burnin = Get-Date
    for($i=$iteration; $i -lt $dateien.Length; $i++){
        $separator = "_"
        $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $dateinamenteile = $dateinamen[$i].Split($separator,$option)
        $filterbefehl = " -i " + $dateien[$i] + " -an -map_metadata -1 -filter_complex `"[0:v]fps=fps=5[tmp1];[tmp1]drawtext=fontsize=12:text=$($dateinamenteile[1]):bordercolor=black:borderw=2:fontcolor=white:x=(w-tw)/2:y=5:alpha=0.8:fontfile=/Windows/Fonts/arial.ttf[vid]`" -map `"[vid]`" -c:v libx264 -intra -crf 18 -preset faster -y -hide_banner -loglevel fatal " + $dateien_dir[$i] + "\\" + $dateinamen[$i] + ".mkv"
        while($prozesse -gt $FloKodiererBurninMultithread){
            $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
            Start-Sleep -Milliseconds 100
        }
        Start-Process -FilePath $FloKodiererBurninEncoder -ArgumentList $filterbefehl -NoNewWindow
        Write-ColorOut "$($i + 1).." -NoNewline
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        if(0 -eq $(($i + 1) % 10)){
            Write-ColorOut " von $($dateien.Length). "
            if(0 -eq $(($i + 1) % 100)){
                $ende_burnin = Get-Date
                $zeitdiff_burnin = New-TimeSpan $anfang_burnin $ende_burnin
                Write-ColorOut "Zeit für Burn-In bisher: $([System.Math]::Floor($zeitdiff_burnin.TotalHours)) Stunden, $($zeitdiff_burnin.Minutes) Min  $($zeitdiff_burnin.Seconds) Sek." -ForegroundColor Cyan
                [Array]$restzeit_burnin = [System.Math]::Floor((($zeitdiff_burnin.TotalHours)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_burnin += [System.Math]::Floor((($zeitdiff_burnin.Minutes)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_burnin += ((($zeitdiff_burnin.Seconds)/$($i+1))*$($dateien.length-($i+1)))
                Write-ColorOut "Geschätzte Zeit bis zum nächsten Schritt:  $($restzeit_burnin[0]):$($restzeit_burnin[1]):$($restzeit_burnin[2])" -ForegroundColor Green
                Write-ColorOut "Erinnerung: Prozess kann mit `"Strg`" + `"C`" unterbrochen werden. " -NoNewline -ForegroundColor Cyan
                Write-ColorOut "PC danach 1min ruhen lassen." -ForegroundColor Green
            }
            Out-File -FilePath $FloKodiererBurninOut\progress_burnin_iteration.txt -InputObject $($i - $FloKodiererBurninMultithread) -Encoding utf8
        }
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    Write-ColorOut "Burn-In-Kodierung fertig." -ForegroundColor Yellow
    Write-ColorOut " "
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_full.txt
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_base.txt
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_dir.txt
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_iteration.txt
    Out-File -FilePath $FloKodiererBurninOut\progress_concat_iteration.txt -InputObject '0' -Encoding utf8
    Start-Sleep -Milliseconds 500
}

#                           $CDrive            $Encoder                   $OutPath            $multithread
Function Flo-KodiererConcat($FloKodiererConcatPath, $FloKodiererConcatEncoder, $FloKodiererConcatOut, $FloKodiererConcatMultithread){
    Write-ColorOut "Suche Dateien zusammen..." -ForegroundColor Yellow
    Set-Location $FloKodiererConcatOut
    $progresstestA = Test-Path -Path $FloKodiererConcatOut\progress_concat_full.txt
    $progresstestB = Test-Path -Path $FloKodiererConcatOut\progress_concat_base.txt
    $progresstestC = Test-Path -Path $FloKodiererConcatOut\progress_concat_iteration.txt
    if($progresstestA -eq $false -or $progresstestB -eq $false -or $progresstestC -eq $false){
        $unterordner = Get-ChildItem -Directory
        $unterordner_pfade = @(ForEach-Object {$unterordner.FullName})
        $unterordner_namen = @(ForEach-Object {$unterordner.BaseName})
        $iteration = 0
        for($i=0; $i -lt $unterordner_pfade.Length; $i++){
            Set-Location $unterordner_pfade[$i]
            for($j=1; $j -le 4; $j ++){
                Copy-Item $FloKodiererConcatPath\cam_dummy_original.mkv .\cam$($j)_dummy.mkv
                $dateien = @(Get-ChildItem cam$($j)*.* -Exclude *.mp4 | ForEach-Object {$_.Name})
                if($dateien.Length -gt 1){
                    for($k=0; $k -lt $dateien.Length; $k++){
                        if($k -eq 0){
                            $bla = "file " + $dateien[$k] | Out-File -Encoding ascii -FilePath .\camera$($j).txt
                        }Else{
                            $bla = "file " + $dateien[$k] | Out-File -Encoding ascii -FilePath .\camera$($j).txt -Append
                        }
                    }
                    (Get-Content .\camera$($j).txt) -replace "\\", "/" -replace "file ", "file `'" -replace ".mkv", ".mkv`'" | Set-Content .\camera$($j).txt
                }Else{
                    Rename-Item .\cam$($j)_dummy.mkv .\camera$($j).mkv
                }
            }
        }
        Out-File -FilePath $FloKodiererConcatOut\progress_concat_full.txt -InputObject $unterordner_pfade -Encoding utf8
        Out-File -FilePath $FloKodiererConcatOut\progress_concat_base.txt -InputObject $unterordner_namen -Encoding utf8
        Out-File -FilePath $FloKodiererQuadOut\progress_concat_iteration.txt -InputObject $iteration -Encoding utf8
    }Else{
        $readerA = [System.IO.File]::OpenText("$FloKodiererConcatOut\progress_concat_full.txt")
        while($null -ne ($lineA = $readerA.ReadLine())) {
            [Array]$unterordner_pfade += $lineA
        }
        $readerA.Close()
        $readerB = [System.IO.File]::OpenText("$FloKodiererConcatOut\progress_concat_base.txt")
        while($null -ne ($lineB = $readerB.ReadLine())) {
            [Array]$unterordner_namen += $lineB
        }
        $readerB.Close()
        $readerC = [System.IO.File]::OpenText("$FloKodiererConcatOut\progress_concat_iteration.txt")
        while($null -ne ($lineC = $readerC.ReadLine())) {
            [int]$iteration = $lineC
            if($iteration -eq -1){
                $iteration = 0
            }
        }
        $readerC.Close()
        Write-ColorOut "Text-Dateien gefunden - setze Arbeit fort bei Ordner Nr. $($iteration + 1)" -ForegroundColor Green
    }
    Write-ColorOut "Schreibe Dateien zusammen für:" -ForegroundColor Yellow
    Write-ColorOut "Diese kann jederzeit unterbrochen und später wiederaufgenommen werden. Mit `"Strg`" + `"C`" unterbrechen, PC danach aber MINDESTENS ZWEI MINUTEN LANG FERTIG RECHNEN LASSEN, d.h. nicht in Standby wechseln oder ausschalten!" -ForegroundColor Cyan
    $anfang_concat = Get-Date
    for($i=$iteration; $i -lt $unterordner_pfade.Length; $i++){
        Write-ColorOut "$($unterordner_namen[$i]) - $($unterordner_pfade.Length - $($i + 1)) Ordner verbleibend.."
        Set-Location $unterordner_pfade[$i]
        for($j=0; $j -lt 4; $j++){
            $dateien = @(Get-ChildItem camera$($j + 1).txt -ErrorAction SilentlyContinue)
            if($dateien -ne 0){
                $filterbefehl = " -f concat -safe 0 -i $($dateien) -an -map_metadata -1 -r 5 -c:v copy -y -hide_banner -loglevel fatal camera$($j + 1).mkv"
                while($prozesse -gt $FloKodiererConcatMultithread){
                   $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
                    Start-Sleep -Milliseconds 100
                }
                Start-Process -FilePath $FloKodiererConcatEncoder -ArgumentList $filterbefehl -NoNewWindow
                $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
                Out-File -FilePath $FloKodiererConcatOut\progress_concat_iteration.txt -InputObject $($i - 1) -Encoding utf8
            }
            if(0 -eq $(($i + 1) % 5)){
                $ende_concat = Get-Date
                $zeitdiff_concat = New-TimeSpan $anfang_concat $ende_concat
                Write-ColorOut "Zeit für Burn-In bisher: $([System.Math]::Floor($zeitdiff_concat.TotalHours)) Stunden, $($zeitdiff_concat.Minutes) Min  $($zeitdiff_concat.Seconds) Sek." -ForegroundColor Cyan
                [Array]$restzeit_concat = [System.Math]::Floor((($zeitdiff_concat.TotalHours)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_concat += [System.Math]::Floor((($zeitdiff_concat.Minutes)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_concat += ((($zeitdiff_concat.Seconds)/$($i+1))*$($dateien.length-($i+1)))
                Write-ColorOut "Geschätzte Zeit bis zum nächsten Schritt:  $($restzeit_concat[0]):$($restzeit_concat[1]):$($restzeit_concat[2])" -ForegroundColor Green
                Write-ColorOut "Erinnerung: Prozess kann mit `"Strg`" + `"C`" unterbrochen werden. " -NoNewline -ForegroundColor Cyan
                Write-ColorOut "PC danach 2min ruhen lassen." -ForegroundColor Green
            }
        }
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    Write-ColorOut "Zusammenschreiben fertig." -ForegroundColor Yellow
    Write-ColorOut " "
    Remove-Item -Path $FloKodiererConcatOut\progress_concat_full.txt
    Remove-Item -Path $FloKodiererConcatOut\progress_concat_base.txt
    Remove-Item -Path $FloKodiererConcatOut\progress_concat_iteration.txt
    Out-File -FilePath $FloKodiererConcatOut\progress_quad_iteration.txt -InputObject '0' -Encoding utf8
    Start-Sleep -Milliseconds 500
}

#                         $Encoder                 $OutPath          $multithread                 $hardware
Function Flo-KodiererQuad($FloKodiererQuadEncoder, $FloKodiererQuadOut, $FloKodiererQuadMultithread, $FloKodiererQuadHardware){
    Write-ColorOut "Beginn Vierfach-Screen-Erstellung..." -ForegroundColor Yellow
    Set-Location $FloKodiererQuadOut
    $progresstestA = Test-Path -Path $FloKodiererQuadOut\progress_quad_full.txt
    $progresstestB = Test-Path -Path $FloKodiererQuadOut\progress_quad_base.txt
    $progresstestC = Test-Path -Path $FloKodiererQuadOut\progress_quad_iteration.txt
    if($progresstestA -eq $false -or $progresstestB -eq $false -or $progresstestC -eq $false){
        $unterordner = Get-ChildItem -Directory
        $unterordner_pfade = @(ForEach-Object {$unterordner.FullName})
        $unterordner_namen = @(ForEach-Object {$unterordner.BaseName})
        $iteration = 0
        Out-File -FilePath $FloKodiererQuadOut\progress_quad_full.txt -InputObject $unterordner_pfade -Encoding utf8
        Out-File -FilePath $FloKodiererQuadOut\progress_quad_base.txt -InputObject $unterordner_namen -Encoding utf8
        Out-File -FilePath $FloKodiererQuadOut\progress_quad_iteration.txt -InputObject $iteration -Encoding utf8
    }Else{
        $readerA = [System.IO.File]::OpenText("$FloKodiererQuadOut\progress_quad_full.txt")
        while($null -ne ($lineA = $readerA.ReadLine())) {
            [Array]$unterordner_pfade += $lineA
        }
        $readerA.Close()
        $readerB = [System.IO.File]::OpenText("$FloKodiererQuadOut\progress_quad_base.txt")
        while($null -ne ($lineB = $readerB.ReadLine())) {
            [Array]$unterordner_namen += $lineB
        }
        $readerB.Close()
        $readerC = [System.IO.File]::OpenText("$FloKodiererQuadOut\progress_quad_iteration.txt")
        while($null -ne ($lineC = $readerC.ReadLine())) {
            [int]$iteration = $lineC
            if($iteration -eq -1){
                $iteration = 0
            }
        }
        $readerC.Close()
        Write-ColorOut "Text-Dateien gefunden - setze Arbeit fort bei Ordner Nr. $($iteration + 1)" -ForegroundColor Green
    }
    Write-ColorOut "Berechne Vierfach-Screen für:" -ForegroundColor Yellow
    Write-ColorOut "Diese kann jederzeit unterbrochen und später wiederaufgenommen werden. Mit `"Strg`" + `"C`" unterbrechen, PC danach aber MINDESTENS FÜNF MINUTEN LANG FERTIG RECHNEN LASSEN, d.h. nicht in Standby wechseln oder ausschalten!" -ForegroundColor Cyan
    $anfang_quad = Get-Date
    for($i=$iteration; $i -lt $unterordner_pfade.Length; $i++){
        Set-Location $unterordner_pfade[$i]
        Write-ColorOut "$($unterordner_namen[$i]) - $($unterordner_pfade.Length - $($i + 1)) Ordner verbleibend.."
        if($FloKodiererQuadHardware -eq $true){
            $filterbefehl = " -i camera1.mkv -i camera2.mkv -i camera3.mkv -i camera4.mkv -filter_complex `"[0:v]setpts=PTS-STARTPTS,scale=320x240[eins];[1:v]setpts=PTS-STARTPTS,scale=320x240[zwei];[2:v]setpts=PTS-STARTPTS,scale=320x240[drei];[3:v]setpts=PTS-STARTPTS,scale=320x240[vier];[eins][zwei]hstack[oben];[drei][vier]hstack[unten];[oben][unten]vstack[vid]`" -map `"[vid]`" -r 5 -map_metadata -1 -c:v h264_qsv -preset slow -q 18 -look_ahead 0 -an -y -hide_banner -loglevel fatal quadscreen.mkv"
            Start-Process -FilePath $FloKodiererQuadEncoder -ArgumentList $filterbefehl -Wait -NoNewWindow
            Start-Sleep -Milliseconds 100
        }Else{
            $filterbefehl = " -i camera1.mkv -i camera2.mkv -i camera3.mkv -i camera4.mkv -filter_complex `"[0:v]setpts=PTS-STARTPTS,scale=320x240[eins];[1:v]setpts=PTS-STARTPTS,scale=320x240[zwei];[2:v]setpts=PTS-STARTPTS,scale=320x240[drei];[3:v]setpts=PTS-STARTPTS,scale=320x240[vier];[eins][zwei]hstack[oben];[drei][vier]hstack[unten];[oben][unten]vstack[vid]`" -map `"[vid]`" -r 5 -map_metadata -1 -c:v libx264 -preset medium -crf 18 -an -y -hide_banner -loglevel fatal quadscreen.mkv"
            while($prozesse -gt $FloKodiererQuadMultithread){
                $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
                Start-Sleep -Milliseconds 100
            }
            Start-Process -FilePath $FloKodiererQuadEncoder -ArgumentList $filterbefehl -NoNewWindow
            $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        }
        if(0 -eq $(($i + 1) % 5)){
            $ende_quad = Get-Date
            $zeitdiff_quad = New-TimeSpan $anfang_quad $ende_quad
            Write-ColorOut "Zeit für Burn-In bisher: $([System.Math]::Floor($zeitdiff_quad.TotalHours)) Stunden, $($zeitdiff_quad.Minutes) Min  $($zeitdiff_quad.Seconds) Sek." -ForegroundColor Cyan
            [Array]$restzeit_quad = [System.Math]::Floor((($zeitdiff_quad.TotalHours)/$($i+1))*$($dateien.length-($i+1)))
            $restzeit_quad += [System.Math]::Floor((($zeitdiff_quad.Minutes)/$($i+1))*$($dateien.length-($i+1)))
            $restzeit_quad += ((($zeitdiff_quad.Seconds)/$($i+1))*$($dateien.length-($i+1)))
            Write-ColorOut "Geschätzte Zeit bis zum nächsten Schritt:  $($restzeit_quad[0]):$($restzeit_quad[1]):$($restzeit_quad[2])" -ForegroundColor Green
            Write-ColorOut "Erinnerung: Prozess kann jederzeit mit `"Strg`" + `"C`" unterbrochen werden. " -NoNewline -ForegroundColor Cyan
            Write-ColorOut "PC danach 5min ruhen lassen." -ForegroundColor Green
        }
        Out-File -FilePath $FloKodiererQuadOut\progress_quad_iteration.txt -InputObject $($i - 1) -Encoding utf8
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    for($i=0; $i -lt $unterordner_pfade.Length; $i++){
        Set-Location $unterordner_pfade[$i]
        Move-Item .\quadscreen.mkv $FloKodiererQuadOut\$($unterordner_namen[$i])_quad.mkv
    }
	Write-ColorOut " "
    Write-ColorOut " "
    Start-Sleep -Seconds 5
	Write-ColorOut "Fertig kodiert!" -ForegroundColor Green
	Write-ColorOut " "
    Remove-Item -Path $FloKodiererQuadOut\progress_quad_full.txt
    Remove-Item -Path $FloKodiererQuadOut\progress_quad_base.txt
    Remove-Item -Path $FloKodiererQuadOut\progress_quad_iteration.txt
    Start-Sleep -Milliseconds 500
}

#                   $OutPath     Zahl f. Usereingabe
Function Flo-Loesch($FloLoeschPath, $FloLoeschUser){
    Set-Location $FloLoeschPath
    if($FloLoeschUser -eq 0){
        Write-ColorOut "Lösche zwischengespeicherte Dateien" -ForegroundColor Yellow
        Get-ChildItem $FloLoeschPath\* -Include *.txt, *.mkv -Recurse | Remove-Item -Include cam*.*
        Write-ColorOut "Löschen beendet!" -ForegroundColor Yellow
    }Else{
        Write-ColorOut "BITTE UM BESTÄTIGUNG!" -ForegroundColor Red -BackgroundColor White
        Write-ColorOut " "
        Write-ColorOut "Dieses Script löscht alle Dateien im Ordner" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-ColorOut " $FloLoeschPath " -NoNewline -ForegroundColor Cyan
        Write-ColorOut "und dessen Unterordnern," -ForegroundColor White -BackgroundColor Red
        Write-ColorOut "die mit" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-ColorOut " `"cam`" " -NoNewline -ForegroundColor Yellow
        Write-ColorOut "beginnen und die Dateiendung" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-ColorOut " `".txt`" " -NoNewline -ForegroundColor Yellow
        Write-ColorOut "oder" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-ColorOut " `".mkv`" " -NoNewline -ForegroundColor Yellow
        Write-ColorOut "tragen!" -ForegroundColor White -BackgroundColor Red
        Write-ColorOut " "
        Write-ColorOut "Sicher, dass der angegebene Ordner stimmt?" -ForegroundColor Red
        $sicher = Read-Host "`"1`" zum Bestätigen, eine andere Ziffer zum Ablehnen. Bestätigung mit Enter"
        Write-ColorOut " "
        if($sicher -eq 1){
            Write-ColorOut "Lösche zwischengespeicherte Dateien" -ForegroundColor Yellow
            Get-ChildItem $FloLoeschPath\* -Include *.txt, *.mkv -Recurse | Remove-Item -Include cam*.*
            Write-ColorOut " "
            Write-ColorOut "Löschen beendet!" -ForegroundColor Yellow
        }Else{
            Write-ColorOut "Abbruch durch Benutzer." -ForegroundColor Green
        }
    }
    Write-ColorOut " "
}

# DEFINITION: Get values for variables from GUI.
Function Get-UserValues(){
    $script:InPath = $script:WPFtextBoxIn.Text
    $script:OutPath = $script:WPFtextBoxOut.Text
    $script:modus = $script:WPFcomboBoxMeth.SelectedIndex
    $script:hardware = $script:WPFcheckBoxHardware.IsChecked
    $script:herunterfahren = $script:WPFcheckBoxShutdown.IsChecked
    $script:multithread = $script:WPFcheckBoxMultithread.IsChecked
    # TODO: from button to function.
    $schonweitertestA = Test-Path -Path $userOutput\progress_burnin_iteration.txt -PathType Leaf
    $schonweitertestB = Test-Path -Path $userOutput\progress_concat_iteration.txt -PathType Leaf
    $schonweitertestC = Test-Path -Path $userOutput\progress_quad_iteration.txt -PathType Leaf
    if($herunterfahren -eq $true -and $debug -eq 0){
        $herunterfahren = 1
    }Else{
        $herunterfahren = 0
    }
    if($multithread -eq $true){
        $cores = Get-WmiObject -class win32_processor
        [int]$multithread = $($cores.NumberOfLogicalProcessors - 1)
    }Else{
        $multithread = 0
    }
}

Function Start-Everything(){
    Write-ColorOut "Hallo bei Flos Überwachungskamera-Skript v3.0!`r`n" -ForegroundColor Cyan
    if($script:debug -ne 0){
        Write-ColorOut "                                                                          " -BackgroundColor Red
        Write-ColorOut "Bitte dieses Fenster zur Analyse von Flo nicht mit `"X`" schließen. Danke!" -ForegroundColor Red -BackgroundColor White
        Write-ColorOut "                                                                          `r`n" -BackgroundColor Red
    }

    Get-UserValues

    $test = (Flo-Test $InPath $OutPath $userMethode)
    
    if($test -eq $true){
        Write-ColorOut "Ab jetzt geht alles automatisch. Danke für die Geduld!" -ForegroundColor Cyan
        Write-ColorOut " "
        $anfang_glob = Get-Date
        Write-ColorOut "Beginn um $(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -ForegroundColor Cyan
        Write-ColorOut " "
        if($stayawake -eq 1){
            Start-Process powershell -ArgumentList "$PSScriptRoot\preventsleep.ps1 -mode 1 -shutdown $userHerunterfahren" -WindowStyle Minimized
        }
        # Option "Kopieren, Kodieren"
        if($modus -eq 0){
            Write-ColorOut "Arbeitsschritte: Kopieren -> Umbenennen -> Kodieren" -ForegroundColor Yellow
            if($herunterfahren -eq 1){
                Write-ColorOut "PC wird nach Beendigung heruntergefahren." -ForegroundColor Green
            }Else{
                Write-ColorOut "PC wird nach Beendigung nicht heruntergefahren." -ForegroundColor Green
            }
            Write-ColorOut " "
            Flo-Copy $InPath $userOutput
            if($debug -eq 1){Pause}
            Flo-Umbenenn $userOutput
            if($debug -eq 1){Pause}
            if($schonweitertestB -eq $false -and $schonweitertestC -eq $false){
                Flo-KodiererBurnin $CDrive $Encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-ColorOut "Burn-In bereits früher durchgeführt." -ForegroundColor Yellow
            }
            if($schonweitertestC -eq $false){
                Flo-KodiererConcat $CDrive $Encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-ColorOut "Zusammenfügen der Dateien bereits früher durchgeführt." -ForegroundColor Yellow
            }
            Flo-KodiererQuad $Encoder $OutPath $multithread $hardware
            if($debug -eq 1){Pause}
            #Flo-Loesch $OutPath 0
        }
        
        # Option "Kodieren"
        if($modus -eq 1){
            Write-ColorOut "Arbeitsschritte: Umbenennen -> Kodieren" -ForegroundColor Yellow
            if($herunterfahren -eq 1){
                Write-ColorOut "PC wird nach Beendigung heruntergefahren." -ForegroundColor Green
            }Else{
                Write-ColorOut "PC wird nach Beendigung nicht heruntergefahren." -ForegroundColor Green
            }
            Write-ColorOut " "
            if($schonweitertestA -eq $false -and $schonweitertestB -eq $false  -and $schonweitertestC -eq $false){
                Flo-Umbenenn $userOutput
                if($debug -eq 1){Pause}
            }Else{
                Write-ColorOut "Umbenennen scheins schon erfolgt." -ForegroundColor Yellow
            }
            if($schonweitertestB -eq $false -and $schonweitertestC -eq $false){
                Flo-KodiererBurnin $CDrive $Encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-ColorOut "Burn-In bereits früher durchgeführt." -ForegroundColor Yellow
            }
            if($schonweitertestC -eq $false){
                Flo-KodiererConcat $CDrive $Encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-ColorOut "Zusammenfügen der Dateien bereits früher durchgeführt." -ForegroundColor Yellow
            }
            Flo-KodiererQuad $Encoder $OutPath $multithread $hardware
            if($debug -eq 1){Pause}
            Flo-Loesch $OutPath 0
        }

        # Option "Loeschen"
        if($modus -eq 2){
            Write-ColorOut "Arbeitsschritte: Löschabfrage`r`n"
            Flo-Loesch $OutPath 1
        }
        $fertig_glob = Get-Date
        $zeitdiff_glob = New-TimeSpan $anfang_glob $fertig_glob
        Write-ColorOut "PROGRAMM FERTIG." -ForegroundColor Green
        Write-ColorOut "End-Zeit: $(Get-Date)" -ForegroundColor Cyan
        Write-ColorOut "Dauer: $([System.Math]::Floor($zeitdiff_glob.TotalHours)) Stunden, $($zeitdiff_glob.Minutes) Min  $($zeitdiff_glob.Seconds) Sek." -ForegroundColor Cyan
    }Else{
        Write-ColorOut "`r`nBitte Eingaben nochmal im Hauptfenster überprüfen." -ForegroundColor Red -BackgroundColor White
    }
}

# ==================================================================================================
# ==============================================================================
#   Programming GUI & starting everything:
# ==============================================================================
# ==================================================================================================

if($GUI_Direct -eq "GUI"){
    # DEFINITION: Setting up GUI:
    <# CREDIT:
        code of this section (except from content of inputXML and small modifications) by
        https://foxdeploy.com/series/learning-gui-toolmaking-series/
    #>
    if((Test-Path -LiteralPath "$($PSScriptRoot)/security-cam_gui.xaml" -PathType Leaf)){
        $inputXML = Get-Content -Path "$($PSScriptRoot)/security-cam_gui.xaml" -Encoding UTF8
    }else{
        Write-ColorOut "Could not find $($PSScriptRoot)/security-cam_gui.xaml - GUI can therefore not start." -ForegroundColor Red
        Pause
        Exit
    }

    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml]$xaml = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:Name",'Name'  -replace '^<Win.*', '<Window'
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    try{$Form=[Windows.Markup.XamlReader]::Load($reader)}
    catch{
        Write-ColorOut "Unable to load Windows.Markup.XamlReader. Usually this means that you haven't installed .NET Framework. Please download and install the latest .NET Framework Web-Installer for your OS: " -ForegroundColor Red
        Write-ColorOut "https://duckduckgo.com/?q=net+framework+web+installer&t=h_&ia=web"
        Write-ColorOut "Alternatively, start this script with '-GUI_Direct `"CLI`"' (w/o single-quotes) to run it via CLI (find other parameters via '-showparams 1' '-Get-Help security-cam_gui.ps1 -detailed'." -ForegroundColor Yellow
        Pause
        Exit
    }
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

    if($getWPF -ne 0){
        Write-ColorOut "Found the following interactable elements:`r`n" -ForegroundColor Cyan
        Get-Variable WPF*
        Pause
        Exit
    }

    # Defining GUI-Values:
    $WPFtextBoxIn.Text = $sd_karte
    $WPFtextBoxOut.Text = $ausgabe
    $WPFcomboBoxMeth.SelectedIndex = $modus
    $WPFcheckBoxHardware.IsChecked = $hardware
    $WPFcheckBoxShutdown.IsChecked = $herunterfahren
    $WPFcheckBoxMultithread.IsChecked = $multithread

    # Defining buttons:
    $WPFbuttonStart.Add_Click({
        $Form.WindowState = 'Minimized'
        Start-Everything
        $Form.WindowState = 'Normal'
    })

    $WPFbuttonSearchIn.Add_Click({Get-Folder("in")})
    $WPFbuttonSearchOut.Add_Click({Get-Folder("out")})
    $WPFbuttonProg.Add_Click({Start-Process powershell -ArgumentList "$($PSScriptRoot)\split_quadscreen.ps1"})
    $WPFbuttonClose.Add_Click({Invoke-Close})

    # Ausgabe von GUI starten:
    $Form.ShowDialog() | out-null
}else{
    Start-Everything
}