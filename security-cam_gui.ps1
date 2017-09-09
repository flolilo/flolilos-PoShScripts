#requires -version 3

<#
    .SYNOPSIS
        Kopiert Video-Dateien von SD-Karte auf Festpatte und kodiert sie dann in eine vierfach-Ansicht.
    .DESCRIPTION
        Benutzt FFmpeg zum Kodieren und Robocopy / Xcopy zum Kopieren.
    .NOTES
        Version:        3.0
        Autor:          Florian Dolzer
        Datum:          25.7.2017
        Rechtliches:    Diese Software ist gratis und darf jederzeit weiterwerwendet und -entwickelt werden (bitte mit Namensnennung). Es wird keine Haftung fuer die Funktion des Skripts - oder durch es entstehende Schaeden in Form von Datenverlust o.Ae. - uebernommen. Der Grossteil des Skripts wurde von mir selbst geschrieben (oder von Quellen aus dem Internet abgeleitet und stark modifiziert). Teile, die Code Dritter enthalten, sind mit dem "#CREDIT"-Tag ausgewiesen.
    .PARAMETER encoder
        Pfad zum Encoder, z.B. "C:\FFMPEG\binaries\ffmpeg.exe"
    .PARAMETER c_platte
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
    [string]$encoder = "C:\FFMPEG\binaries\ffmpeg.exe",
    [string]$c_platte = "C:\FFMPEG",
    [string]$sd_karte = "",
    [string]$ausgabe = "",
    [int]$modus = 0,
    [int]$hardware = 0,
    [int]$multithread = 1,
    [int]$stayawake = 1,
    [int]$herunterfahren = 0,
    [int]$debug = 0
    
)

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

# Usual ErrorAction: Stop: https://stackoverflow.com/a/21260623/8013879
# Set standard ErrorAction to 'Stop':
$PSDefaultParameterValues = @{}
$PSDefaultParameterValues += @{'*:ErrorAction' = 'Stop'}
$ErrorActionPreference = 'Stop'

# If you want to see the variables (buttons, checkboxes, ...) the GUI has to offer, set this to 1:
[int]$getWPF = 0

# ==================================================================================================
# ==============================================================================
# Defining Functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: "Select"-Window for buttons to choose a path.
Function Get-Folder($InOut){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
    $folderdialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderdialog.rootfolder = "MyComputer"
    if($folderdialog.ShowDialog() -eq "OK"){
        if($InOutMirror -eq "input"){$script:WPFtextBoxInput.Text = $folderdialog.SelectedPath}
        if($InOutMirror -eq "output"){$script:WPFtextBoxOutput.Text = $folderdialog.SelectedPath}
    }
}

#                 $InPath  $OutPath  $userMethode
Function Flo-Test($FloTestIn, $FloTestOut, $FloTestMode){
    Write-Host "Bitte noch kurz hier bleiben, Skript überprüft Verzeichnis-Eingabe..." -ForegroundColor Cyan
    if($FloTestMode -eq 0){
        $eingangsordner = Test-Path -LiteralPath $FloTestIn -pathType container
        if($eingangsordner -eq $true){
            Set-Location $FloTestIn
            #Set-Location ..
            [String]$movieordner = (Resolve-Path .\).Path
            # $movieordner = (Get-ChildItem -Directory -Filter 'Movies').count
            if($movieordner -notlike '*Movies'){
                Write-Host "Eingans-Ordner enthält keinen Ordner namens `"Movies`". Sicher, dass die Auswahl stimmt?" -ForegroundColor Red
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
            Write-Host "Eingangs-Ordner nicht gefunden!" -ForegroundColor Red
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
                        Write-Host "Ausgangs-Ordner enthält bereits Dateien. Das kann zu unvorhergesehenem Verhalten des Programs führen." -ForegroundColor Red
                        Write-Host "Es wird empfohlen, alle Ordner und/oder Dateien im Pfad `"$FloTestOut`" an eine andere Stelle zu kopieren und erst dann fortzufahren, oder einen anderen Ausgabeordner zu wählen." -ForegroundColor Red
                    }Else{
                        Write-Host "Zuvor abgebrochene Sitzung erkannt." -ForegroundColor Red
                        Write-Host "Bitte einfach mit `"Nein`" zum Hauptfenster zurückkehren und von dort aus mit der Option `"Kodieren`" erneut beginnen." -ForegroundColor Red
                        Write-Host " "
                    }
                    Write-Host "Mit dem Kopieren fortfahren?" -ForegroundColor Yellow
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
                Write-Host "Ausgangs-Ordner nicht gefunden!" -ForegroundColor Red
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
	Write-Host "Kopiere..." -ForegroundColor Yellow
    start-process robocopy.exe -ArgumentList "`"$FloCopyIn`" `"$FloCopyOut`" *.mp4 /S /V /R:100 /W:10 /MT:8" -Wait -NoNewWindow
	Write-Host "Kopieren beendet!" -ForegroundColor Yellow
    Write-Host " "
    Start-Sleep -Seconds 10
}

#                     $userOutput
Function Flo-Umbenenn($FloUmbenennOut){
	Write-Host "Starte Umbenennung der Ordner und Dateien..."  -ForegroundColor Yellow
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
    Write-Host "Ummbenennung fertig." -ForegroundColor Yellow
    Write-Host " "
}

#                           $c_platte            $encoder                   $OutPath            $multithread
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
        Write-Host "Text-Dateien gefunden - setze Arbeit fort bei Datei Nr. $($iteration + 1) von $($dateien.Length)" -ForegroundColor Green
    }
	Write-Host "Starte Burn-In-Kodierung der Dateinamen in Video..."  -ForegroundColor Yellow
    Write-Host "Diese kann jederzeit unterbrochen und später wiederaufgenommen werden. Mit `"Strg`" + `"C`" unterbrechen, PC danach aber MINDESTENS EINE MINUTE LANG FERTIG RECHNEN LASSEN, d.h. nicht in Standby wechseln oder ausschalten!" -ForegroundColor Cyan
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
        Write-Host "$($i + 1).." -NoNewline
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        if(0 -eq $(($i + 1) % 10)){
            Write-Host " von $($dateien.Length). "
            if(0 -eq $(($i + 1) % 100)){
                $ende_burnin = Get-Date
                $zeitdiff_burnin = New-TimeSpan $anfang_burnin $ende_burnin
                Write-Host "Zeit für Burn-In bisher: $([System.Math]::Floor($zeitdiff_burnin.TotalHours)) Stunden, $($zeitdiff_burnin.Minutes) Min  $($zeitdiff_burnin.Seconds) Sek." -ForegroundColor Cyan
                [Array]$restzeit_burnin = [System.Math]::Floor((($zeitdiff_burnin.TotalHours)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_burnin += [System.Math]::Floor((($zeitdiff_burnin.Minutes)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_burnin += ((($zeitdiff_burnin.Seconds)/$($i+1))*$($dateien.length-($i+1)))
                Write-Host "Geschätzte Zeit bis zum nächsten Schritt:  $($restzeit_burnin[0]):$($restzeit_burnin[1]):$($restzeit_burnin[2])" -ForegroundColor Green
                Write-Host "Erinnerung: Prozess kann mit `"Strg`" + `"C`" unterbrochen werden. " -NoNewline -ForegroundColor Cyan
                Write-Host "PC danach 1min ruhen lassen." -ForegroundColor Green
            }
            Out-File -FilePath $FloKodiererBurninOut\progress_burnin_iteration.txt -InputObject $($i - $FloKodiererBurninMultithread) -Encoding utf8
        }
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    Write-Host "Burn-In-Kodierung fertig." -ForegroundColor Yellow
    Write-Host " "
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_full.txt
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_base.txt
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_dir.txt
    Remove-Item -Path $FloKodiererBurninOut\progress_burnin_iteration.txt
    Out-File -FilePath $FloKodiererBurninOut\progress_concat_iteration.txt -InputObject '0' -Encoding utf8
    Start-Sleep -Milliseconds 500
}

#                           $c_platte            $encoder                   $OutPath            $multithread
Function Flo-KodiererConcat($FloKodiererConcatPath, $FloKodiererConcatEncoder, $FloKodiererConcatOut, $FloKodiererConcatMultithread){
    Write-Host "Suche Dateien zusammen..." -ForegroundColor Yellow
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
        Write-Host "Text-Dateien gefunden - setze Arbeit fort bei Ordner Nr. $($iteration + 1)" -ForegroundColor Green
    }
    Write-Host "Schreibe Dateien zusammen für:" -ForegroundColor Yellow
    Write-Host "Diese kann jederzeit unterbrochen und später wiederaufgenommen werden. Mit `"Strg`" + `"C`" unterbrechen, PC danach aber MINDESTENS ZWEI MINUTEN LANG FERTIG RECHNEN LASSEN, d.h. nicht in Standby wechseln oder ausschalten!" -ForegroundColor Cyan
    $anfang_concat = Get-Date
    for($i=$iteration; $i -lt $unterordner_pfade.Length; $i++){
        Write-Host "$($unterordner_namen[$i]) - $($unterordner_pfade.Length - $($i + 1)) Ordner verbleibend.."
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
                Write-Host "Zeit für Burn-In bisher: $([System.Math]::Floor($zeitdiff_concat.TotalHours)) Stunden, $($zeitdiff_concat.Minutes) Min  $($zeitdiff_concat.Seconds) Sek." -ForegroundColor Cyan
                [Array]$restzeit_concat = [System.Math]::Floor((($zeitdiff_concat.TotalHours)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_concat += [System.Math]::Floor((($zeitdiff_concat.Minutes)/$($i+1))*$($dateien.length-($i+1)))
                $restzeit_concat += ((($zeitdiff_concat.Seconds)/$($i+1))*$($dateien.length-($i+1)))
                Write-Host "Geschätzte Zeit bis zum nächsten Schritt:  $($restzeit_concat[0]):$($restzeit_concat[1]):$($restzeit_concat[2])" -ForegroundColor Green
                Write-Host "Erinnerung: Prozess kann mit `"Strg`" + `"C`" unterbrochen werden. " -NoNewline -ForegroundColor Cyan
                Write-Host "PC danach 2min ruhen lassen." -ForegroundColor Green
            }
        }
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    Write-Host "Zusammenschreiben fertig." -ForegroundColor Yellow
    Write-Host " "
    Remove-Item -Path $FloKodiererConcatOut\progress_concat_full.txt
    Remove-Item -Path $FloKodiererConcatOut\progress_concat_base.txt
    Remove-Item -Path $FloKodiererConcatOut\progress_concat_iteration.txt
    Out-File -FilePath $FloKodiererConcatOut\progress_quad_iteration.txt -InputObject '0' -Encoding utf8
    Start-Sleep -Milliseconds 500
}

#                         $encoder                 $OutPath          $multithread                 $hardware
Function Flo-KodiererQuad($FloKodiererQuadEncoder, $FloKodiererQuadOut, $FloKodiererQuadMultithread, $FloKodiererQuadHardware){
    Write-Host "Beginn Vierfach-Screen-Erstellung..." -ForegroundColor Yellow
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
        Write-Host "Text-Dateien gefunden - setze Arbeit fort bei Ordner Nr. $($iteration + 1)" -ForegroundColor Green
    }
    Write-Host "Berechne Vierfach-Screen für:" -ForegroundColor Yellow
    Write-Host "Diese kann jederzeit unterbrochen und später wiederaufgenommen werden. Mit `"Strg`" + `"C`" unterbrechen, PC danach aber MINDESTENS FÜNF MINUTEN LANG FERTIG RECHNEN LASSEN, d.h. nicht in Standby wechseln oder ausschalten!" -ForegroundColor Cyan
    $anfang_quad = Get-Date
    for($i=$iteration; $i -lt $unterordner_pfade.Length; $i++){
        Set-Location $unterordner_pfade[$i]
        Write-Host "$($unterordner_namen[$i]) - $($unterordner_pfade.Length - $($i + 1)) Ordner verbleibend.."
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
            Write-Host "Zeit für Burn-In bisher: $([System.Math]::Floor($zeitdiff_quad.TotalHours)) Stunden, $($zeitdiff_quad.Minutes) Min  $($zeitdiff_quad.Seconds) Sek." -ForegroundColor Cyan
            [Array]$restzeit_quad = [System.Math]::Floor((($zeitdiff_quad.TotalHours)/$($i+1))*$($dateien.length-($i+1)))
            $restzeit_quad += [System.Math]::Floor((($zeitdiff_quad.Minutes)/$($i+1))*$($dateien.length-($i+1)))
            $restzeit_quad += ((($zeitdiff_quad.Seconds)/$($i+1))*$($dateien.length-($i+1)))
            Write-Host "Geschätzte Zeit bis zum nächsten Schritt:  $($restzeit_quad[0]):$($restzeit_quad[1]):$($restzeit_quad[2])" -ForegroundColor Green
            Write-Host "Erinnerung: Prozess kann jederzeit mit `"Strg`" + `"C`" unterbrochen werden. " -NoNewline -ForegroundColor Cyan
            Write-Host "PC danach 5min ruhen lassen." -ForegroundColor Green
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
	Write-Host " "
    Write-Host " "
    Start-Sleep -Seconds 5
	Write-Host "Fertig kodiert!" -ForegroundColor Green
	Write-Host " "
    Remove-Item -Path $FloKodiererQuadOut\progress_quad_full.txt
    Remove-Item -Path $FloKodiererQuadOut\progress_quad_base.txt
    Remove-Item -Path $FloKodiererQuadOut\progress_quad_iteration.txt
    Start-Sleep -Milliseconds 500
}

#                   $OutPath     Zahl f. Usereingabe
Function Flo-Loesch($FloLoeschPath, $FloLoeschUser){
    Set-Location $FloLoeschPath
    if($FloLoeschUser -eq 0){
        Write-Host "Lösche zwischengespeicherte Dateien" -ForegroundColor Yellow
        Get-ChildItem $FloLoeschPath\* -Include *.txt, *.mkv -Recurse | Remove-Item -Include cam*.*
        Write-Host "Löschen beendet!" -ForegroundColor Yellow
    }Else{
        Write-Host "BITTE UM BESTÄTIGUNG!" -ForegroundColor Red -BackgroundColor White
        Write-Host " "
        Write-Host "Dieses Script löscht alle Dateien im Ordner" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-Host " $FloLoeschPath " -NoNewline -ForegroundColor Cyan
        Write-Host "und dessen Unterordnern," -ForegroundColor White -BackgroundColor Red
        Write-Host "die mit" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-Host " `"cam`" " -NoNewline -ForegroundColor Yellow
        Write-Host "beginnen und die Dateiendung" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-Host " `".txt`" " -NoNewline -ForegroundColor Yellow
        Write-Host "oder" -NoNewline -ForegroundColor White -BackgroundColor Red
        Write-Host " `".mkv`" " -NoNewline -ForegroundColor Yellow
        Write-Host "tragen!" -ForegroundColor White -BackgroundColor Red
        Write-Host " "
        Write-Host "Sicher, dass der angegebene Ordner stimmt?" -ForegroundColor Red
        $sicher = Read-Host "`"1`" zum Bestätigen, eine andere Ziffer zum Ablehnen. Bestätigung mit Enter"
        Write-Host " "
        if($sicher -eq 1){
            Write-Host "Lösche zwischengespeicherte Dateien" -ForegroundColor Yellow
            Get-ChildItem $FloLoeschPath\* -Include *.txt, *.mkv -Recurse | Remove-Item -Include cam*.*
            Write-Host " "
            Write-Host "Löschen beendet!" -ForegroundColor Yellow
        }Else{
            Write-Host "Abbruch durch Benutzer." -ForegroundColor Green
        }
    }
    Write-Host " "
}

# DEFINITION: For the auditory experience:
Function Start-Sound($success){
    $sound = new-Object System.Media.SoundPlayer -ErrorAction SilentlyContinue
    if($success -eq 1){
        $sound.SoundLocation = "c:\WINDOWS\Media\tada.wav"
    }else{
        $sound.SoundLocation = "c:\WINDOWS\Media\chimes.wav"
    }
    $sound.Play()
}

Function Invoke-Pause(){
    if($script:debug -ne 0){
        Pause
    }
}

Function Invoke-Close($closing){
    if($script:debug -ne 0){
        Write-Host "Flo sagt: BITTE FENSTER NICHT SCHLIESSEN!" -ForegroundColor Red -BackgroundColor White
        Write-Host "Flo möchte nämlich dieses Fenster auf Programmier-Fehler untersuchen. Danke!`r`n" -ForegroundColor Cyan
        $ende = 0
        while($ende -ne 28){
            $ende = Read-Host "Falls diese Bitte nicht fruchtet: `"28`" eingeben (ohne Anführungszeichen). Bestätigen mit Enter"
        }
        Pause
    }
    if($closing -eq 1){
        $script:Form.Close()
        Exit
    }
}

Function Start-Everything(){
    Write-Host "Hallo bei Flos Überwachungskamera-Skript v3.0!`r`n" -ForegroundColor Cyan
    if($script:debug -ne 0){
        Write-Host "                                                                          " -BackgroundColor Red
        Write-Host "Bitte dieses Fenster zur Analyse von Flo nicht mit `"X`" schließen. Danke!" -ForegroundColor Red -BackgroundColor White
        Write-Host "                                                                          " -BackgroundColor Red
        Write-Host " " 
    }
}

# ==================================================================================================
# ==============================================================================
# Programming GUI & starting everything:
# ==============================================================================
# ==================================================================================================

# GUI-Code (XAML)
$inputXML = @"
<Window x:Class="FlosFFmpegSkripte.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        mc:Ignorable="d"
        Title="Flos Ü-Kamera-Prog v3.0" Height="323" Width="735" ResizeMode="CanMinimize">
    <Grid Background="#FFB3B6B5">
        <TextBlock x:Name="textBlockWelcome" HorizontalAlignment="Left" Margin="112,20,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="32" Width="520" FontSize="18" TextAlignment="Center" Text="Willkommen bei Flos Überwachungskamera-Programm v3.0!"/>
        <TextBlock x:Name="textBlockInput" HorizontalAlignment="Left" Margin="13,72,0,0" TextWrapping="Wrap" Text="Pfad SD-Karte:" VerticalAlignment="Top" Height="18" Width="80"/>
        <TextBlock x:Name="textBlockOutput" HorizontalAlignment="Left" Margin="25,115,0,0" TextWrapping="Wrap" Text="Pfad am PC:" VerticalAlignment="Top" Height="18"/>
        <TextBlock x:Name="textBlockMethode" HorizontalAlignment="Left" Margin="185,159,0,0" TextWrapping="Wrap" Text="Was soll getan werden?" VerticalAlignment="Top" Height="22"/>
        <Button x:Name="buttonStart" Content="START" HorizontalAlignment="Center" Margin="285,259,332,0" VerticalAlignment="Top" Width="110" HorizontalContentAlignment="Center" ToolTip="Tipp: Verzeichnisse vor Beginn überprüfen!"/>
        <Button x:Name="buttonClose" Content="Ende" HorizontalAlignment="Left" Margin="619,259,0,0" VerticalAlignment="Top" Width="60" ToolTip="Ciao!"/>
        <Button x:Name="buttonSearchIn" Content="Durchsuchen..." HorizontalAlignment="Left" Margin="619,70,0,0" VerticalAlignment="Top" Width="90" Height="24"/>
        <Button x:Name="buttonSearchOut" Content="Durchsuchen..." HorizontalAlignment="Left" Margin="619,113,0,0" VerticalAlignment="Top" Width="90" Height="24"/>
        <Button x:Name="buttonProg" Content="Datei-Splitter" HorizontalAlignment="Left" Margin="50,259,0,0" VerticalAlignment="Top" Width="105" ToolTip="Zum Herausrechnen wichtiger Stellen."/>
        <TextBox x:Name="textBoxInput" HorizontalAlignment="Left" Height="23" Margin="103,71,0,0" Text="sd-karten_inhalt\Movies" VerticalAlignment="Top" Width="500" ToolTip="SD-Karten-Verzeichnis. Nur nötig, falls auch kopiert wird." VerticalScrollBarVisibility="Disabled"/>
        <TextBox x:Name="textBoxOutput" HorizontalAlignment="Left" Height="23" Margin="103,113,0,0" Text="X:\_NEUE_DATEIEN" VerticalAlignment="Top" Width="500" ToolTip="Ziel-Verzeichnis." VerticalScrollBarVisibility="Disabled"/>
        <CheckBox x:Name="checkBoxHardware" Content="Hardware-Codierung" HorizontalAlignment="Left" Margin="200,192,0,0" VerticalAlignment="Top" ToolTip="Wenn aktiviert: geht schneller, kann aber Fehler erzeugen. Empfehlung: Bei Monika AN, bei Franz AUS." IsChecked="True" Width="153" Padding="4,-1,0,0"/>
        <CheckBox x:Name="checkBoxShutdown" Content="Nach Beendigung herunterfahren (keine Funktion bei &quot;Zwischendateien löschen&quot;)" HorizontalAlignment="Left" Margin="200,211,0,0" VerticalAlignment="Top" ToolTip="Wenn alles fertig ist, fährt Computer herutner. Vorteilhaft, wenn Programm über Nacht läuft." Width="459" Padding="4,-1,0,0"/>
        <CheckBox x:Name="checkBoxMultithread" Content="Multithreading" HorizontalAlignment="Left" Margin="200,231,0,0" VerticalAlignment="Top" Padding="4,-1,0,0" IsChecked="True" ToolTip="Rechnet effizienter, PC ist aber daneben kaum noch nutzbar. Gut, wenn über Nacht gerechnet wird."/>
        <ComboBox x:Name="comboBoxMeth" HorizontalAlignment="Left" Margin="318,156,0,0" VerticalAlignment="Top" Width="186" IsReadOnly="True" SelectedIndex="0" ToolTip="Empfehlung: Standard-Auswahl.">
            <ComboBoxItem Content="Kopieren &amp; Kodieren"/>
            <ComboBoxItem Content="Kodieren"/>
            <ComboBoxItem Content="Zwischendateien löschen"/>
        </ComboBox>
    </Grid>
</Window>
"@
 
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$xaml = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:Name",'Name'  -replace '^<Win.*', '<Window'
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try{$Form=[Windows.Markup.XamlReader]::Load($reader)}
catch{
    Write-Host "Unable to load Windows.Markup.XamlReader. Usually this means that you haven't installed .NET Framework. Please download and install the latest .NET Framework Web-Installer for your OS: " -NoNewline -ForegroundColor Red
    Write-Host "https://www.google.com/webhp?q=net+framework+web+installer"
    Write-Host "Alternatively, start this script with '-GUI_CLI_Direct `"CLI`"' (w/o single-quotes) to run it via CLI (find other parameters via '-Help 2' or via README-File ('-Help 1')." -ForegroundColor Yellow
    Pause
    Exit
}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

if($getWPF -ne 0){
    Write-Host "Found the following interactable elements:`r`n" -ForegroundColor Cyan
    Get-Variable WPF*
    Pause
    Exit
}

# Defining GUI-Values:
$WPFtextBoxInput.Text = $sd_karte
$WPFtextBoxOutput.Text = $ausgabe
$WPFcomboBoxMeth.SelectedIndex = $modus
$WPFcheckBoxHardware.IsChecked = $hardware
$WPFcheckBoxShutdown.IsChecked = $herunterfahren
$WPFcheckBoxMultithread.IsChecked = $multithread

#===========================================================================
#===========================================================================
# Programming the buttons:
#===========================================================================

$WPFbuttonStart.Add_Click({
    $script:InPath = $script:WPFtextBoxInput.Text
    $script:OutPath = $script:WPFtextBoxOutput.Text
    $script:modus = $script:WPFcomboBoxMeth.SelectedIndex
    $script:hardware = $script:WPFcheckBoxHardware.IsChecked
    $script:herunterfahren = $script:WPFcheckBoxShutdown.IsChecked
    $script:multithread = $script:WPFcheckBoxMultithread.IsChecked
    $schonweitertestA = Test-Path -Path $userOutput\progress_burnin_iteration.txt
    $schonweitertestB = Test-Path -Path $userOutput\progress_concat_iteration.txt
    $schonweitertestC = Test-Path -Path $userOutput\progress_quad_iteration.txt
    if($herunterfahren -eq $true -and $debug -eq 0){
        $herunterfahren = 1
    }Else{
        $herunterfahren = 0
    }
    if($multithread -eq $true){
        $cores = Get-WmiObject -class win32_processor
        [int]$multithread = $cores.NumberOfLogicalProcessors
        $multithread--
    }Else{
        $multithread = 0
    }
    $Form.WindowState = 'Minimized'
    $test = (Flo-Test $InPath $OutPath $userMethode)
    if($test -eq $true){
        Write-Host "Ab jetzt geht alles automatisch. Danke für die Geduld!" -ForegroundColor Cyan
        Write-Host " "
        $anfang_glob = Get-Date
        Write-Host "Beginn um $(Get-Date -Format 'dd.MM.yy, HH:mm:ss')" -ForegroundColor Cyan
        Write-Host " "
        if($stayawake -eq 1){
            Start-Process powershell -ArgumentList "$PSScriptRoot\preventsleep.ps1 -mode 1 -shutdown $userHerunterfahren" -WindowStyle Minimized
        }
        # Option "Kopieren, Kodieren"
        if($modus -eq 0){
            Write-Host "Arbeitsschritte: Kopieren -> Umbenennen -> Kodieren" -ForegroundColor Yellow
            if($herunterfahren -eq 1){
                Write-Host "PC wird nach Beendigung heruntergefahren." -ForegroundColor Green
            }Else{
                Write-Host "PC wird nach Beendigung nicht heruntergefahren." -ForegroundColor Green
            }
            Write-Host " "
            Flo-Copy $InPath $userOutput
            if($debug -eq 1){Pause}
            Flo-Umbenenn $userOutput
            if($debug -eq 1){Pause}
            if($schonweitertestB -eq $false -and $schonweitertestC -eq $false){
                Flo-KodiererBurnin $c_platte $encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-Host "Burn-In bereits früher durchgeführt." -ForegroundColor Yellow
            }
            if($schonweitertestC -eq $false){
                Flo-KodiererConcat $c_platte $encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-Host "Zusammenfügen der Dateien bereits früher durchgeführt." -ForegroundColor Yellow
            }
            Flo-KodiererQuad $encoder $OutPath $multithread $hardware
            if($debug -eq 1){Pause}
            #Flo-Loesch $OutPath 0
        }
        
        # Option "Kodieren"
        if($modus -eq 1){
            Write-Host "Arbeitsschritte: Umbenennen -> Kodieren" -ForegroundColor Yellow
            if($herunterfahren -eq 1){
                Write-Host "PC wird nach Beendigung heruntergefahren." -ForegroundColor Green
            }Else{
                Write-Host "PC wird nach Beendigung nicht heruntergefahren." -ForegroundColor Green
            }
            Write-Host " "
            if($schonweitertestA -eq $false -and $schonweitertestB -eq $false  -and $schonweitertestC -eq $false){
                Flo-Umbenenn $userOutput
                if($debug -eq 1){Pause}
            }Else{
                Write-Host "Umbenennen scheins schon erfolgt." -ForegroundColor Yellow
            }
            if($schonweitertestB -eq $false -and $schonweitertestC -eq $false){
                Flo-KodiererBurnin $c_platte $encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-Host "Burn-In bereits früher durchgeführt." -ForegroundColor Yellow
            }
            if($schonweitertestC -eq $false){
                Flo-KodiererConcat $c_platte $encoder $OutPath $multithread
                if($debug -eq 1){Pause}
            }Else{
                Write-Host "Zusammenfügen der Dateien bereits früher durchgeführt." -ForegroundColor Yellow
            }
            Flo-KodiererQuad $encoder $OutPath $multithread $hardware
            if($debug -eq 1){Pause}
            Flo-Loesch $OutPath 0
        }

        # Option "Loeschen"
        if($modus -eq 2){
            Write-Host "Arbeitsschritte: Löschabfrage"
            Write-Host " "
            Flo-Loesch $OutPath 1
        }
        $fertig_glob = Get-Date
        $zeitdiff_glob = New-TimeSpan $anfang_glob $fertig_glob
        Write-Host "PROGRAMM FERTIG." -ForegroundColor Green
        Write-Host "End-Zeit: $(Get-Date)" -ForegroundColor Cyan
        Write-Host "Dauer: $([System.Math]::Floor($zeitdiff_glob.TotalHours)) Stunden, $($zeitdiff_glob.Minutes) Min  $($zeitdiff_glob.Seconds) Sek." -ForegroundColor Cyan
    }Else{
        Write-Host " "
        Write-Host "Bitte Eingaben nochmal im Hauptfenster überprüfen." -ForegroundColor Red -BackgroundColor White
    }
    Invoke-Close(0)
    $Form.WindowState = 'Normal'
})

$WPFbuttonSearchIn.Add_Click({
    Get-Folder("in")
})

$WPFbuttonSearchOut.Add_Click({
    Get-Folder("out")
})

$WPFbuttonProg.Add_Click({
    Start-Process powershell -ArgumentList "$PSScriptRoot\flo_split_quadscreen.ps1"
})

$WPFbuttonClose.Add_Click({
    Invoke-Close(1)
})



# Ausgabe von GUI starten:
$Form.ShowDialog() | out-null
