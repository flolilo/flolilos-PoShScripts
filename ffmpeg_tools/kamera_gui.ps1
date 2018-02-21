# Flos Ueberwachungskamera-Tool, v2.7, 2017-03-07
# Tested with PowerShell 5.1 (Win10)
# BEWARE: This script is an OLD version of security-cam_gui.ps1
# 
param(
    [string]$paraEncoder = "C:\FFMPEG\binaries\ffmpeg.exe", # Pfad zu ffmeg.exe
	[string]$paraInput="SD-KartenLaufwerk:\Movies",
	[string]$paraOutput="X:\_NEUE_DATEIEN",
	[int]$paraMeth=0,
	[int]$paraMultiThread=1,
	[int]$paraHardware=0,
	[int]$paraShutdown=0,
	[int]$paraGUI=1,
    [int]$paraRememberIn = 0,
    [int]$paraRememberOut = 0,
    [int]$paraRememberPara = 0,
    [int]$paraShowParas = 0,
    [int]$debug = 0 # 1 pauses after exit, 2 after every function
)
[int]$paramline = 4
[string]$filterFormat = "*.mp4"

<# FALLS DIE PARAMETER VERLOREN GEHEN:
    [string]$paraEncoder = "C:\FFMPEG\binaries\ffmpeg.exe", # Pfad zu ffmeg.exe
	[string]$paraInput="SD-KartenLaufwerk:\Movies",
	[string]$paraOutput="X:\_NEUE_DATEIEN",
	[int]$paraMeth=0,
	[int]$paraMultiThread=1,
	[int]$paraHardware=0,
	[int]$paraShutdown=0,
	[int]$paraGUI=1,
    [int]$paraRememberIn = 0,
    [int]$paraRememberOut = 0,
    [int]$paraRememberPara = 0,
    [int]$paraShowParas = 0,
    [int]$debug = 0 # 1 pauses after exit, 2 after every function
ENDE DES PARAMETER-BACKUPS #>

if($paraShowParas -ne 0){
    Write-Host "Flos Ueberwachungskamera-Tool Parameter:" -ForegroundColor Green
    Write-Host " "
    Write-Host "-paraEncoder = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraEncoder -ForegroundColor Yellow
    Write-Host "-paraInput = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraInput -ForegroundColor Yellow
    Write-Host "-paraOutput = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraOutput -ForegroundColor Yellow
    Write-Host "-paraMeth = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraMeth -ForegroundColor Yellow
    Write-Host "-paraMultiThread = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraMultiThread -ForegroundColor Yellow
    Write-Host "-paraHardware = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraHardware -ForegroundColor Yellow
    Write-Host "-paraShutdown = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraShutdown -ForegroundColor Yellow
    Write-Host "-paraGUI = " -NoNewline -ForegroundColor Cyan
    Write-Host $paraGUI -ForegroundColor Yellow
    Write-Host " "
    Pause
    Exit
}

#===============================================================================
#===============================================================================
# Setting up the GUI:
#===============================================================================

$inputXML = @"
<Window x:Class="FlosFFmpegSkripte.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:FlosFFmpegSkripte"
        mc:Ignorable="d"
        Title="Flos Ueberwachungskamera-Prog v2.6" Height="280" Width="800" ResizeMode="CanMinimize">
    <Grid Background="#FFB3B6B5">
        <TextBlock x:Name="textBlockInput" Text="Pfad SD-Karte:" HorizontalAlignment="Left" Margin="20,23,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="80" TextAlignment="Right"/>
        <TextBox x:Name="textBoxInput" Text="Input" ToolTip="SD-Karten-Verzeichnis. Nur noetig, falls auch kopiert wird." HorizontalAlignment="Left" Height="23" Margin="110,20,0,0" VerticalAlignment="Top" Width="500" VerticalScrollBarVisibility="Disabled" VerticalContentAlignment="Center"/>
        <Button x:Name="buttonSearchIn" Content="Pfad..." HorizontalAlignment="Right" Margin="0,20,90,0" VerticalAlignment="Top" Width="80" Height="23"/>
        <CheckBox x:Name="checkBoxRememberIn" Content="Merken" ToolTip="Pfad d. SD-Karte merken" Foreground="#FFC90000" HorizontalAlignment="Right" Margin="0,24,20,0" VerticalAlignment="Top" Width="65" VerticalContentAlignment="Center"/>
        <TextBlock x:Name="textBlockOutput" Text="Pfad am PC:" HorizontalAlignment="Left" Margin="20,53,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="80" TextAlignment="Right"/>
        <TextBox x:Name="textBoxOutput" Text="Output" ToolTip="Ziel-Verzeichnis." HorizontalAlignment="Left" Height="23" Margin="110,50,0,0" VerticalAlignment="Top" Width="500" VerticalScrollBarVisibility="Disabled" VerticalContentAlignment="Center"/>
        <Button x:Name="buttonSearchOut" Content="Pfad..." HorizontalAlignment="Right" Margin="0,50,90,0" VerticalAlignment="Top" Width="80" Height="23"/>
        <CheckBox x:Name="checkBoxRememberOut" Content="Merken" ToolTip="Pfad am PC od. Server merken" Foreground="#FFC90000" HorizontalAlignment="Right" Margin="0,54,20,0" VerticalAlignment="Top" Width="65" VerticalContentAlignment="Center"/>
        <TextBlock x:Name="textBlockMeth" Text="Was soll getan werden?" HorizontalAlignment="Center" Margin="0,84,150,0" TextWrapping="Wrap" VerticalAlignment="Top"/>
        <ComboBox x:Name="comboBoxMeth" ToolTip="Empfehlung: Standard-Auswahl." HorizontalAlignment="Center" Margin="150,80,0,0" VerticalAlignment="Top" IsReadOnly="True" SelectedIndex="0" Height="23" VerticalContentAlignment="Center" Width="150">
            <ComboBoxItem Content="Kopieren und Kodieren" ToolTip="Normale Funktion."/>
            <ComboBoxItem Content="Kodieren" ToolTip="Kopieren wird uebersprungen."/>
            <ComboBoxItem Content="Zwischendateien loeschen" ToolTip="Nur falls mal abgebrochen wurde."/>
        </ComboBox>
        <CheckBox x:Name="checkBoxMultithread" Content="Multithreading" ToolTip="Rechnet effizienter, PC ist aber daneben kaum noch nutzbar. Gut, wenn ueber Nacht gerechnet wird." HorizontalAlignment="Center" Margin="0,115,0,0" VerticalAlignment="Top" Width="175"/>
        <CheckBox x:Name="checkBoxHardware" Content="Hardware-Codierung" ToolTip="Wenn aktiviert: geht schneller, kann aber Fehler erzeugen. Empfehlung: Bei Monika AN, bei Franz AUS." HorizontalAlignment="Center" Margin="0,135,0,0" VerticalAlignment="Top" Width="175"/>
        <CheckBox x:Name="checkBoxShutdown" Content="Nach Beendigung herunterfahren" ToolTip="Wenn alles fertig ist, faehrt Computer herutner. Vorteilhaft, wenn Programm ueber Nacht laeuft." Foreground="#FF0064B4" HorizontalAlignment="Center" Margin="30,155,0,0" VerticalAlignment="Top" Width="205"/>
        <TextBlock x:Name="textBlockShutdown" Text="(deaktiv. b. &quot;Zwischendateien loeschen&quot;)" Foreground="#FF0064B4" HorizontalAlignment="Center" Margin="80,175,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="215"/>
        <Button x:Name="buttonProg" Content="Datei-Splitter" ToolTip="Zum Herausrechnen wichtiger Stellen." HorizontalAlignment="Left" Margin="50,0,0,20" VerticalAlignment="Bottom" Width="110" Height="23"/>
        <Button x:Name="buttonStart" Content="START" ToolTip="Tipp: Verzeichnisse vor Beginn ueberpruefen!" HorizontalAlignment="Center" Margin="0,0,80,20" VerticalAlignment="Bottom" Width="110" HorizontalContentAlignment="Center" Height="23"/>
        <CheckBox x:Name="checkBoxRememberPara" Content="Einstellungen merken" ToolTip="Alle Einstellungen (ausser Merk-Einstellungen) merken." HorizontalAlignment="Center" Margin="180,0,0,22" VerticalAlignment="Bottom" Foreground="#FFC90000"/>
        <Button x:Name="buttonClose" Content="Ende" ToolTip="Ciao!" HorizontalAlignment="Right" Margin="0,0,50,20" VerticalAlignment="Bottom" Width="110" Height="23"/>
    </Grid>
</Window>
"@
if($script:paraGUI -ne 0){
    $inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:Name",'Name'  -replace '^<Win.*', '<Window'
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml]$XAML = $inputXML
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    try{$Form=[Windows.Markup.XamlReader]::Load($reader)}
    catch{
        Write-Host "Kann Windows.Markup.XamlReader nicht laden. Normalerweise ist .NET Framework nicht installiert. Bitte den neuesten .NET Framework Web-Installer fuer das jeweilige Betriebssystem Downloaden und installieren: https://www.google.at/webhp?q=net+framework+web+installer" -ForegroundColor Red
        Write-Host "Alternativ dieses Skript mit '-paraGUI 0' (ohne Anfuerhungszeichen) starten um es in der Kommandozeilen-Version zu starten (andere Parameter via '-showParas 1' oder via README-Datei herausfinden." -ForegroundColor Yellow
        Pause
        Exit
    }
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

    # If you want to see the variables the GUI has to offer, set this to 1:
    [int]$programmierung = 0
    if($programmierung -ne 0){
        if ($global:ReadmeDisplay -ne $true){
            Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow
            $global:ReadmeDisplay=$true
        }
        write-host "Found the following interactable elements:" -ForegroundColor Cyan
        get-variable WPF*
    }

    # Fill the TextBoxes with user aparameters:
    $WPFtextBoxInput.Text = $paraInput
    $WPFtextBoxOutput.Text = $paraOutput
    $WPFcomboBoxMeth.SelectedIndex = $paraMeth
    $WPFcheckBoxMultithread.IsChecked = $paraMultiThread
    $WPFcheckBoxHardware.IsChecked = $paraHardware
    $WPFcheckBoxShutdown.IsChecked = $paraShutdown
    $WPFcheckBoxRememberIn.IsChecked = $paraRememberIn
    $WPFcheckBoxRememberOut.IsChecked = $paraRememberOut
    $WPFcheckBoxRememberPara.IsChecked = $paraRememberPara
}else{
    Clear-Variable -Name inputXML*
}

#===============================================================================
#===============================================================================
# Setting up Functions:
#===============================================================================

# DEFINITION: "Select"-Window for buttons to choose a path:
Function Get-Folder($InOrOut){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
    $folderdialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderdialog.rootfolder = "MyComputer"
    if($folderdialog.ShowDialog() -eq "OK"){
        if($InOrOut -eq "input"){$script:WPFtextBoxInput.Text = $folderdialog.SelectedPath}
        if($InOrOut -eq "output"){$script:WPFtextBoxOutput.Text = $folderdialog.SelectedPath}
    }
}

# DEFINITION: Get all values from user:
Function Get-UserValues(){
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Variablen von GUI / Parametern holen..." -ForegroundColor Cyan
    if($script:paraGUI -ne 0){
        if(!([regex]::Escape($script:WPFtextBoxInput.Text) -match [regex]::Escape('[') -or [regex]::Escape($script:WPFtextBoxInput.Text) -match [regex]::Escape(']') -or [regex]::Escape($script:WPFtextBoxInput.Text) -match [regex]::Escape('|'))){
            $script:paraInput = $script:WPFtextBoxInput.Text
            $korrektIn = 1
        }else{
            Write-Host 'Eckige Klammern [ ] und Pipes | sind im Quellpfad nicht erlaubt. Tut mir leid...' -ForegroundColor Red
            $korrektIn = 0
        }
        if(!([regex]::Escape($script:WPFtextBoxOutput.Text) -match [regex]::Escape('[') -or [regex]::Escape($script:WPFtextBoxOutput.Text) -match [regex]::Escape(']') -or [regex]::Escape($script:WPFtextBoxOutput.Text) -match [regex]::Escape('|'))){
            $script:paraOutput = $script:WPFtextBoxOutput.Text
            $korrektOut = 1
        }else{
            Write-Host 'Eckige Klammern [ ] und Pipes | sind im Zielpfad nicht erlaubt. Tut mir leid...' -ForegroundColor Red
            $korrektOut = 0
        }
        $script:paraMeth = $script:WPFcomboBoxMeth.SelectedIndex
        $script:paraMultiThread = $script:WPFcheckBoxMultithread.IsChecked
        $script:paraHardware = $script:WPFcheckBoxHardware.IsChecked
        $script:paraShutdown = $script:WPFcheckBoxShutdown.IsChecked
        $script:paraRememberIn = $script:WPFcheckBoxRememberIn.IsChecked
        $script:paraRememberOut = $script:WPFcheckBoxRememberOut.IsChecked
        $script:paraRememberPara = $script:WPFcheckBoxRememberPara.IsChecked
    }else{
        if([regex]::Escape($script:paraInput) -match [regex]::Escape('[') -or [regex]::Escape($script:paraInput) -match [regex]::Escape(']') -or [regex]::Escape($scriptparaInput.Text) -match [regex]::Escape('|')){
            Write-Host 'Eckige Klammern [ ] und Pipes | sind im Quellpfad nicht erlaubt. Tut mir leid...' -ForegroundColor Red
            $korrektIn = 0
        }else{
            $korrektIn = 1
        }
        if([regex]::Escape($script:paraOutput) -match [regex]::Escape('[') -or [regex]::Escape($script:paraOutput) -match [regex]::Escape(']') -or [regex]::Escape($script:paraOutput) -match [regex]::Escape('|')){
            Write-Host 'Eckige Klammern [ ] und Pipes | sind im Zielpfad nicht erlaubt. Tut mir leid...' -ForegroundColor Red
            $korrektOut = 0
        }else{
            $korrektOut = 1
        }
    }
    $script:harddrive = $script:paraOutput.Substring(0, $script:paraOutput.IndexOf(":"))
    if($korrektIn -ne 0 -and $korrektOut -ne 0){
        Write-Host "Alles okay..." -ForegroundColor Green
        return $true
    }else{
        Write-Host "Nix is okay!" -ForegroundColor Red
        return $false
    }
}

# DEFINITION: Test paths:
Function Test-UserPaths(){
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Quell- und Zielpfad testen..." -ForegroundColor Cyan
    if($script:paraInput -eq $script:paraOutput){
        Write-Host "Quellpfad = Zielpfad. Bitte unterschiedliche, valide Pfade angeben!" -ForegroundColor Red
        return $false
    }elseif($script:paraInput.Length -le 1 -or (Test-Path -Path $script:paraInput) -eq $false){
        Write-Host "Falscher Quellpfad. Bitte einen validen Pfad angeben!" -ForegroundColor Red
        return $false
    }elseif($script:paraOutput.Length -le 1 -or (Test-Path -Path $script:paraOutput) -eq $false){
        if((Split-Path -parent $script:paraOutput).Length -ne 0 -and (Test-Path -Path (Split-Path -parent $script:paraOutput) -ErrorAction SilentlyContinue) -eq $true){
            Write-Host "Zielpfad nicht existent, aber Ueberverzeichnis gefunden. Soll das Verzeichnis erstellt werden?" -ForegroundColor Magenta
            if((Read-Host "'1' (ohne Anfuehrungszeichen) fuer `"ja`", andere Ziffer um den Zielpfad neu auszuwaehlen. Bestaetigen mit Enter") -eq 1){
                try{
                    New-Item -Path $script:paraOutput -ItemType Directory | Out-Null
                    Write-Host "$script:paraOutput erstellt." -ForegroundColor Green
                    return $true
                }
                catch{
                    Write-Host "$script:paraOutput konnte nicht erstellt werden - Abbruch!" -ForegroundColor Red
                    return $false
                }
            }else{
                Write-Host "Falscher Zielpfad. Bitte einen validen Pfad angeben." -ForegroundColor Red
                return $false
            }
        }else{
            Write-Host "Falscher Zielpfad. Bitte einen validen Pfad angeben." -ForegroundColor Red
            return $false
        }
    }else{
        return $true
    }
}

# DEFINITION: If checked, remember values for future use:
Function Start-Remembering(){
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Einstellungen merken (falls gewaehlt)..." -ForegroundColor Cyan

    if($script:paraRememberIn -ne 0){
        $lines = (Get-Content $PSCommandPath)
        Write-Host "Von:`t" -NoNewline; Write-Host $lines[$($script:paramline + 1)] -ForegroundColor Gray
        $lines[$($script:paramline + 1)] = "`t" + '[string]$paraInput=' + "`"$script:paraInput`","
        Write-Host "Zu:`t" -NoNewline; Write-Host $lines[$($script:paramline + 1)] -ForegroundColor Yellow
        $lines | Set-Content $PSCommandPath -Encoding UTF8
    }
    if($script:paraRememberOut -ne 0){
        $lines = (Get-Content $PSCommandPath)
        Write-Host "Von:`t" -NoNewline; Write-Host $($lines[$($script:paramline + 2)]) -ForegroundColor Gray
        $lines[$($script:paramline + 2)] = "`t" + '[string]$paraOutput=' + "`"$script:paraOutput`","
        Write-Host "Zu:`t" -NoNewline; Write-Host $($lines[$($script:paramline + 2)]) -ForegroundColor Yellow
        $lines | Set-Content $PSCommandPath -Encoding UTF8
    }
    if($script:paraRememberPara -ne 0){
        $lines = (Get-Content $PSCommandPath)
        Write-Host "Von:"
        for($i = $($script:paramline + 3); $i -le $($paramline + 7); $i++){
            Write-Host "$($lines[$i])" -ForegroundColor Gray
        }
        $lines[$($script:paramline + 3)] = "`t" + '[int]$paraMeth=' + "$script:paraMeth,"
        $lines[$($script:paramline + 4)] = "`t" + '[int]$paraMultiThread=' + "$script:paraMultiThread,"
        $lines[$($script:paramline + 5)] = "`t" + '[int]$paraHardware=' + "$script:paraHardware,"
        $lines[$($script:paramline + 6)] = "`t" + '[int]$paraShutdown=' + "$script:paraShutdown,"
        $lines[$($script:paramline + 7)] = "`t" + '[int]$paraGUI=' + "$script:paraGUI,"
        Write-Host "Zu:"
        for($i = $($script:paramline + 3); $i -le $($paramline + 7); $i++){
            Write-Host "$($lines[$i])" -ForegroundColor Gray
        }
        $lines | Set-Content $PSCommandPath -Encoding UTF8
    }
    if($script:paraMultiThread -ne 0){$script:paraMultiThread = 3}else{$script:paraMultiThread = 0}
}

# DEFINITION: Searching for selected formats in Input-Path, getting Path, Name, Time, and calculating Hash:
Function Start-FileSearchAndCheck(){
    # Search files and get some information about them:
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Suche Dateien zusammen, pruefe auf bereits kopierte..." -ForegroundColor Cyan
    [int]$gci = 1
    Write-Host "Suche Dateien auf SD-Karte:`t" -ForegroundColor Yellow
    [array]$script:infile_all = @(Get-ChildItem -Path $script:paraOut -Include $script:filterFormat -Recurse | ForEach-Object {Write-Host "$gci " -ForegroundColor Gray -NoNewline; $gci++; $_})
    [array]$infile_all_path = @($script:infile_all.FullName)
    [array]$infile_all_format = @($script:infile_all.Extension)
    [array]$infile_all_date = $script:infile_all | ForEach-Object {$_.LastWriteTime.ToString("yyyy-MM-dd")}
    [array]$infile_all_time = $script:infile_all | ForEach-Object {$_.LastWriteTime.ToString("HH-mm-ss")}
    [array]$infile_all_size = $script:infile_all | ForEach-Object {$_.Length / 1kB}
    [array]$infile_all_change = $script:infile_all | ForEach-Object {$_.LastWriteTime.ToString("yyyy-MM-dd_HH-mm-ss")}
    Write-Host "`r`n`r`n$($infile_all_path.Length)" -NoNewline -ForegroundColor DarkYellow; Write-Host  " Dateien auf SD-Karte gefunden.`r`n" -ForegroundColor Yellow
    [int]$gci = 1
    Write-Host "Suche Dateien im Zielpfad:`t" -ForegroundColor Yellow
    [array]$existingfile_all = @(Get-ChildItem -Path $script:paraOut -Include $script:FilterFormat -Recurse | ForEach-Object {Write-Host "$gci " -ForegroundColor Gray -NoNewline; $gci++; $_})
    [array]$existingfile_all_path = @($existingfile_all.FullName)
    [array]$existingfile_all_all_size = $existingfile_all | ForEach-Object {$_.Length / 1kB}
    [array]$existingfile_all_all_change = $existingfile_all | ForEach-Object {$_.LastWriteTime.ToString("yyyy-MM-dd_HH-mm-ss")}
    Write-Host "`r`n`r`n$($existingfile_all_path.Length)" -NoNewline -ForegroundColor DarkYellow; Write-Host  " Dateien im Zielpfad gefunden.`r`n" -ForegroundColor Yellow
    Invoke-Pause

    if($existingfile_all_path.Length -eq 0){
        Write-Host "Ueberpruefung auf Duplikate sinnlos, da Zielordner leer ist. Weiter im Programm..." -ForegroundColor Green
        [array]$script:infile_sort_path = $infile_all_path
        [array]$script:infile_sort_format = $infile_all_format
        [array]$script:infile_sort_date = $infile_all_date
        [array]$script:infile_sort_time = $infile_all_time
        [array]$script:infile_sort_size = $infile_all_size
    }else{
        Write-Host "Ueberpruefe auf Duplikate:`t" -ForegroundColor Yellow
        [array]$duplicate_index = @()
        for($i = 0; $i -lt $infile_all_path.Length; $i++){
            $j = 0
            while($true){
                if($infile_all_change[$i] -eq $existingfile_all_change[$j] -and $infile_all_size[$i] -eq $existingfile_all_all_size[$j]){
                    $duplicate_index += $i
                    Write-Host "$($i + 1) " -ForegroundColor DarkGreen
                    break
                }else{
                    if($j -ge $existingfile_all_path.Length){
                        Write-Host "$($i + 1) " -ForegroundColor Gray
                        break
                    }
                    $j++
                    continue
                }
            }
        }
        [array]$script:infile_sort_path = @()
        [array]$script:infile_sort_format = @()
        [array]$script:infile_sort_date = @()
        [array]$script:infile_sort_time = @()
        [array]$script:infile_sort_size = @()
        [array]$script:infile_sort_change = @()
        for($i = 0; $i -lt $infile_all_path.Length; $i++){
            if(!($i -in $duplicate_index)){
                $script:infile_sort_path += $infile_all_path[$i]
                $script:infile_sort_format += $infile_all_format[$i]
                $script:infile_sort_date += $infile_all_date[$i]
                $script:infile_sort_time += $infile_all_time[$i]
                $script:infile_sort_size += $infile_all_size[$i]
                $script:infile_sort_change += $infile_all_change[$i]
            }
        }
    }
    Clear-Variable -Name infile_all_*, existingfile*

    Write-Host "Auf Kopieren vorbereiten..." -ForegroundColor Cyan
    [array]$script:outfile_path = @()
    [array]$inter = @()
    [array]$interfolder = @()
    [array]$script:outfile_path = @()
    [array]$script:copystring = @()
    for($i = 0; $i -lt $script:infile_sort_path.Length; $i++){
        $inter = @("$($script:paraOut)\$($script:infile_sort_date[$i])\$($script:infile_sort_time[$i])$($script:infile_sort_format[$i])")
        if((Test-Path -Path "$inter") -eq $false){
            if($script:debug -ne 0){Write-Host "`r`n$($script:infile_sort_time[$i])" -NoNewline; Write-Host "`t- File 404" -ForegroundColor Green -NoNewline}
            $j = 1
            while($true){
                if($inter -in $script:outfile_path){
                    if($script:debug -ne 0){Write-Host " - $($j - 1) (already in variable)" -NoNewline}
                    $inter = @("$($script:paraOut)\$($script:infile_sort_date[$i])\$($script:infile_sort_time[$i])_file$j$($script:infile_sort_format[$i])")
                    $j++
                    continue
                }else{
                    if($script:debug -ne 0){Write-Host " - $($j - 1) (Original)" -NoNewline}
                    $script:outfile_path += $inter
                    $script:copystring += $inter.Replace($($script:infile_sort_format[$i]),'')
                    Break
                }
            }
        }Else{
            $j = 1
            $inter = @("$($script:paraOut)\$($script:infile_sort_date[$i])\$($script:infile_sort_time[$i])_copy$j$($script:infile_sort_format[$i])")
            if($script:debug -ne 0){Write-Host "`r`n$($script:infile_sort_time[$i])" -NoNewline; Write-Host "`t- File Found" -ForegroundColor Magenta -NoNewline}
            while($true){
                if((Test-Path -Path "$inter") -eq $false){
                    if(!($inter -in $script:outfile_path)){
                        if($script:debug -ne 0){Write-Host " - copy$j okay." -NoNewline}
                        $script:outfile_path += $inter
                        $script:copystring += $inter.Replace($($script:infile_sort_format[$i]),'')
                        break
                    }else{
                        $k = 1
                        while($true){
                            $inter = @("$($script:paraOut)\$($script:infile_sort_date[$i])\$($script:infile_sort_time[$i])_copy$j_file$k$($script:infile_sort_format[$i])")
                            if(!($inter -in $script:outfile_path)){
                                if($script:debug -ne 0){Write-Host " - copy$j file$k okay." -NoNewline}
                                $script:outfile_path += $inter
                                $script:copystring += $inter.Replace($($script:infile_sort_format[$i]),'')
                                break
                            }else{
                                if($script:debug -ne 0){Write-Host " - copy$j file$k already in variable." -NoNewline}
                                $k++
                                continue
                            }
                        }
                        break
                    }
                }Else{
                    if($script:debug -ne 0){Write-Host " - copy$j also on HDD." -NoNewline}
                    $j++
                    Continue
                }
            }
        }
    }
}

# DEFINITION: Copy Files
Function Start-FileCopy(){
    $activeProcessCounter = 0
    for($i = 0; $i -lt $script:outfile_path.Length; $i++){
        if(($script:secondattempt -eq 1 -and $i -in $script:brokenfile_index) -or ($script:secondattempt -eq 0)){
            while($activeProcessCounter -gt $script:paraMultiThread){
                $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name xcopy).count
                Start-Sleep -Milliseconds 75
            }
            Write-Host "$($i + 1)/$($script:outfile_path.Length): " -NoNewLine
            $inter = ($($script:infile_sort_path[$i]).Replace($script:paraInput,'.')) + "`t"
            Write-Host $inter -NoNewLine -ForegroundColor Cyan
            Write-Host "-> "  -NoNewLine
            $inter = ($($script:outfile_path[$i]).Replace($script:paraOutput,'.'))
            Write-Host $inter -ForegroundColor Yellow
            Start-Process xcopy -ArgumentList "`"$($script:infile_sort_path[$i])`" `"$($script:copystring[$i]).*`" /q /i /j /-y" -WindowStyle Hidden
            Start-Sleep -Milliseconds 1
            $activeProcessCounter++
        }
    }
    # When finished copying, wait until all xcopy-instances are done:
    while($activeProcessCounter -gt 0){
        $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name xcopy).count
        Start-Sleep -Milliseconds 75
    }
    Start-Sleep -Seconds 5
}

# DEFINITION: Verify newly copied files
Function Start-FileVerification(){
    if($script:secondattempt -ne 0){
        [array]$notyetbroken = $script:brokenfile_index
    }
    [array]$script:brokenfile_index = @()
    [array]$outfile_all = Get-ChildItem -Path $script:outfile_path
    $outfile_size = $outfile_all | ForEach-Object {$_.Length / 1kB}
    $outfile_change = $outfile_all | ForEach-Object {$_.LastWriteTime.ToString("yyyy-MM-dd_HH-mm-ss")}
    for($i = 0; $i -lt $script:outfile_path.Length; $i++){
        if($script:secondattempt -eq 1 -and $i -in $notyetbroken -or $script:secondattempt -eq 0){
            if((Test-Path -Path "$($script:outfile_path[$i])") -eq $true){
                if($($script:infile_sort_size[$i]) -ne $($script:outfile_size[$i]) -and $script:infile_sort_change -ne $script:outfile_change){
                    Write-Host "$($i + 1) " -NoNewline -ForegroundColor Red
                    $script:brokenfile_index += $i
                    Rename-Item -Path "$($script:outfile_path[$i])" -NewName "$($script:outfile_path[$i])_broken"
                }else{
                    Write-Host "$($i + 1) " -NoNewline -ForegroundColor DarkGreen
                    [array]$script:verifile_all += $outfile_all[$i]
                }
            }else{
                Write-Host "$($i + 1)" -NoNewline -ForegroundColor White -BackgroundColor Red; Write-Host " " -NoNewline
                $script:brokenfile_index += $i
                New-Item -Path "$($script:outfile_path[$i])_broken" | Out-Null
            }
        }
    }
    if($script:brokenfile_index.Length -ne 0){
        Write-Host "`r`n`r`nFEHLERHAFTE DATEI(EN):" -ForegroundColor Red
        for($i = 0; $i -lt $script:outfile_path.Length; $i++){
            if($i -in $script:brokenfile_index){
                Write-Host $script:outfile_path[$i]
            }
        }
        Write-Host " "
    }Else{
        Write-Host "`r`n`r`nAlle Dateien erfolgreich kopiert!`r`n" -ForegroundColor Green
    }
    [array]$script:verifile_all_path = $script:verifile_all | ForEach-Object {$_.FullName}
    [array]$script:verifile_all_date = $script:verifile_all | ForEach-Object {$_.LastWriteTime.ToString("yyyy-MM-dd")}
    [array]$script:verifile_all_time = $script:verifile_all | ForEach-Object {$_.LastWriteTime.ToString("HH-mm-ss")}

}

# DEFINITION: Burnin-Coding:
Function Start-KodiererBurnin(){
	Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Brenne Zeitangabe in Videodateien ein..."  -ForegroundColor Cyan

    if($para:userMeth -ne 0){
        $verifile_all = (Get-ChildItem -Path "$script:paraOutput" -Include $script:filterFormat -Recurse)
        $script:verifile_all_path = $verifile_all | ForEach-Object {$_.FullName}
        $script:verifile_all_path = $verifile_all | ForEach-Object {$_.FullName}
    }
	Push-Location -Path $Env:WinDir -StackName "KameraGUI"
    [int]$activeProcessCounter = 0
    for($i=0; $i -lt $script:verifile_all_path.Length; $i++){
        $verifile_all_path_woExtension = $($script:verifile_all_path[$i]).Substring(0, $($script:verifile_all_path[$i]).lastIndexOf('.'))
        $filterbefehl = " -i " + $script:verifile_all_path[$i] + " -an -map_metadata -1 -filter_complex `"[0:v]fps=fps=5[tmp1];[tmp1]drawtext=fontsize=12:text=$($verifile_all_time[$i]):bordercolor=black:borderw=2:fontcolor=white:x=(w-tw)/2:y=5:alpha=0.8:fontfile=/Windows/Fonts/arial.ttf[vid]`" -map `"[vid]`" -c:v libx264 -intra -crf 16 -preset fast -y -hide_banner -loglevel fatal $($verifile_all_path_woExtension).mkv"
        while($activeProcessCounter -gt $script:paraMultiThread){
            $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
            Start-Sleep -Milliseconds 50
        }
        Start-Process -FilePath "$script:paraEncoder" -ArgumentList $filterbefehl -NoNewWindow
        Write-Host "$($i + 1)/$($script:verifile_all_path.Length)`t" -NoNewline -ForegroundColor Gray
        $activeProcessCounter++
    }

    while($activeProcessCounter -ne 0){
        $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    Pop-Location -StackName "KameraGUI"
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Burn-In-Kodierung fertig.`r`n"  -ForegroundColor Green
}

# DEFINITION: Start concatenate:
Function Start-KodiererConcat(){
	Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Suche Dateien zusammen..."  -ForegroundColor Cyan

    [array]$script:unterordner_name = @(Sort-Object -InputObject $script:verifile_all_date -Unique)

    for($i=0; $i -lt $script:unterordner_name.Length; $i++){
        for($j=1; $j -le 4; $j ++){
            try{Copy-Item "$($PSScriptRoot)\cam_dummy_original.mkv" "$script:paraOutput\$($script:unterordner_name[$i])\cam$($j)_dummy.mkv"}
            catch{Write-Host "Konnte $($PSScriptRoot)\cam_dummy_original.mkv nicht finden. Bitte sicherstellen, dass Datei im selben Ordner ist wie dieses Skript ($($PSScriptRoot)) und Enter druecken." -ForegroundColor Red; continue}
            Start-Sleep -Milliseconds 100
            $filesForConcat = @(Get-ChildItem "$script:paraOutput\$($script:unterordner_name[$i])\cam$($j)*.*" -Exclude $script:filterFormat | ForEach-Object {$_.Name})
            if($filesForConcat.Length -gt 1){
                for($k=0; $k -lt $filesForConcat.Length; $k++){
                    $("file " + $($filesForConcat[$k])) | Out-File -Encoding ascii -FilePath "$script:paraOutput\$($script:unterordner_name[$i])\camera$($j).txt" -Append
                }
                (Get-Content "$script:paraOutput\$($script:unterordner_name[$i])\camera$($j).txt") -replace "\\", "/" -replace "file ", "file `'" -replace ".mkv", ".mkv`'" | Set-Content "$script:paraOutput\$($script:unterordner_name[$i])\camera$($j).txt"
            }Else{
                Rename-Item "$script:paraOutput\$($script:unterordner_name[$i])\cam$($j)_dummy.mkv" "$script:paraOutput\$($script:unterordner_name[$i])\camera$($j).mkv"
            }
        }
    }

    Write-Host "Schreibe Dateien zusammen fuer..." -ForegroundColor Yellow
    [int]$activeProcessCounter = 0
    for($i=0; $i -lt $script:unterordner_name.Length; $i++){
        Write-Host $script:unterordner_name[$i] -ForegroundColor Yellow
        for($j=0; $j -lt 4; $j++){
            $fileConcatText = @(Get-ChildItem "$script:paraOutput\$($script:unterordner_name[$i])\camera$($j + 1).txt" -ErrorAction SilentlyContinue | ForEach-Object {$_.FullName})
            if($fileConcatText.Length -ne 0){
                $filterbefehl = " -f concat -safe 0 -i `"$($fileConcatText)`" -an -map_metadata -1 -r 5 -c:v copy -y -hide_banner -loglevel fatal `"$script:paraOutput\$($script:unterordner_name[$i])\camera$($j + 1).mkv`""
                while($activeProcessCounter -gt $paraMultiThread){
                    $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
                    Start-Sleep -Milliseconds 50
                }
                Start-Process -FilePath "$script:paraEncoder" -ArgumentList $filterbefehl -NoNewWindow
                Start-Sleep -Milliseconds 1
                [array]$script:file_concat_path += "$script:paraOutput\$($script:unterordner_name[$i])\camera$($j + 1).mkv"
                $activeProcessCounter++
            }else{
                [array]$script:file_concat_path += "$script:paraOutput\$($script:unterordner_name[$i])\camera$($j + 1).mkv"
            }
        }
    }
    while($activeProcessCounter -ne 0){
        $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Zusammenschreiben fertig.`r`n" -ForegroundColor Green
}

# DEFINITION: Start Quad-Coding:
Function Start-KodiererQuad(){
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Beginn Vierfach-Screen-Erstellung..." -ForegroundColor Cyan

    [array]$unterordner_alle = @(Get-ChildItem -Directory)
    [array]$unterordner_pfade = @($unterordner_alle | ForEach-Object {$_.FullName})
    [array]$unterordner_namen = @($unterordner_alle | ForEach-Object {$_.BaseName})
    "$($script:paraOutput)\$($script:unterordner_name[$i])\"
    
    [int]$activeProcessCounter = 0
    for($i=0; $i -lt $unterordner_name.Length; $i++){
        if($script:paraHardware -eq $true){
            $filterbefehl = " -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera1.mkv`" -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera2.mkv`" -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera3.mkv`" -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera4.mkv`" -filter_complex `"[0:v]setpts=PTS-STARTPTS,scale=320x240[eins];[1:v]setpts=PTS-STARTPTS,scale=320x240[zwei];[2:v]setpts=PTS-STARTPTS,scale=320x240[drei];[3:v]setpts=PTS-STARTPTS,scale=320x240[vier];[eins][zwei]hstack[oben];[drei][vier]hstack[unten];[oben][unten]vstack[vid]`" -map `"[vid]`" -r 5 -map_metadata -1 -c:v h264_qsv -preset veryslow -q 18 -look_ahead 0 -an -y -hide_banner -loglevel fatal `"$($script:paraOutput)\$($script:unterordner_name[$i])\quadscreen.mkv`""
            Start-Process -FilePath "$script:paraEncoder" -ArgumentList $filterbefehl -Wait -NoNewWindow
            Start-Sleep -Milliseconds 100
        }Else{
            $filterbefehl = " -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera1.mkv`" -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera2.mkv`" -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera3.mkv`" -i `"$($script:paraOutput)\$($script:unterordner_name[$i])\camera4.mkv`" -filter_complex `"[0:v]setpts=PTS-STARTPTS,scale=320x240[eins];[1:v]setpts=PTS-STARTPTS,scale=320x240[zwei];[2:v]setpts=PTS-STARTPTS,scale=320x240[drei];[3:v]setpts=PTS-STARTPTS,scale=320x240[vier];[eins][zwei]hstack[oben];[drei][vier]hstack[unten];[oben][unten]vstack[vid]`" -map `"[vid]`" -r 5 -map_metadata -1 -c:v libx264 -preset slow -crf 18 -an -y -hide_banner -loglevel fatal `"$($script:paraOutput)\$($script:unterordner_name[$i])\quadscreen.mkv`""
            while($activeProcessCounter -gt $script:paraMultiThread){
                $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
                Start-Sleep -Milliseconds 50
            }
            Write-Host "$($unterordner_name[$i])`t" -NoNewline -ForegroundColor Yellow
            Start-Process -FilePath "$script:paraEncoder" -ArgumentList $filterbefehl -NoNewWindow
            Start-Sleep -Milliseconds 1
            $activeProcessCounter++
        }
        
    }
    while($activeProcessCounter -ne 0){
        $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    for($i=0; $i -lt $unterordner_name.Length; $i++){
        Move-Item "$($script:paraOutput)\$($script:unterordner_name[$i])\quadscreen.mkv" "$script:paraOutput\$($unterordner_namen[$i])_quad.mkv" | Out-Null
    }
    Start-Sleep -Seconds 5
	Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Fertig kodiert!`r`n" -ForegroundColor Green
}

# DEFINITION: Delete old files Zahl f. Usereingabe
Function Start-Loesch($LoeschUser){
    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Starte Loesch-Funktion f. Zwischendateien..." -ForegroundColor Cyan
    while($true){
        if($LoeschUser -ne 0){
            Write-Host "BITTE UM BESTAETIGUNG!`r`n" -ForegroundColor Red -BackgroundColor White
            Write-Host "Dieses Script loescht alle Dateien im Ordner" -NoNewline -ForegroundColor White -BackgroundColor Red
            Write-Host " $script:paraOutput " -NoNewline -ForegroundColor Cyan
            Write-Host "und dessen Unterordnern," -ForegroundColor White -BackgroundColor Red
            Write-Host "die mit" -NoNewline -ForegroundColor White -BackgroundColor Red
            Write-Host " `"cam`" " -NoNewline -ForegroundColor Yellow
            Write-Host "beginnen und die Dateiendung" -NoNewline -ForegroundColor White -BackgroundColor Red
            Write-Host " `".txt`" " -NoNewline -ForegroundColor Yellow
            Write-Host "oder" -NoNewline -ForegroundColor White -BackgroundColor Red
            Write-Host " `".mkv`" " -NoNewline -ForegroundColor Yellow
            Write-Host "tragen!`r`n" -ForegroundColor White -BackgroundColor Red
            Write-Host "Sicher, dass der angegebene Ordner ( `"$script:paraOutput`" ) stimmt?" -ForegroundColor Red
            [int]$sicher = Read-Host "`"1`" zum Bestaetigen, eine andere Ziffer zum Ablehnen. Bestaetigung mit Enter"
            Write-Host " "
            if($sicher -ne 1){
                Write-Host "Abbruch durch Benutzer." -ForegroundColor Green
                break
            }
        }
        Write-Host "Loesche zwischengespeicherte Dateien..." -ForegroundColor Yellow
        Get-ChildItem "$script:paraOutput\*" -Include *.txt, *.mkv -Recurse | Remove-Item -Include cam*.*
        Start-Sleep -Seconds 5
        Start-Process powershell -ArgumentList "Write-VolumeCache -DriveLetter $script:harddrive" -WindowStyle Hidden -Wait
        Start-Sleep -Seconds 1
        Write-Host "$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - Loeschen beendet!`r`n" -ForegroundColor Green
        break
    }
}

# DEFINITION: Pause the programme if debug-var is active.
Function Invoke-Pause(){
    if($script:debug -eq 2){Pause}
}

# DEFINITION: Exit the program (and close all windows) + option to pause before exiting.
Function Invoke-Close(){
    if($script:paraGUI -ne 0){$script:Form.Close()}
    if($script:debug -ne 0){Pause}
    Exit
}

# DEFINITION: For the auditory experience:
Function Start-Sound($success){
    $sound = new-Object System.Media.SoundPlayer -ErrorAction SilentlyContinue
    if($success -eq 1){
        $sound.SoundLocation="c:\WINDOWS\Media\tada.wav"
        $sound.Play()
    }else{
        $sound.SoundLocation="c:\WINDOWS\Media\chimes.wav"
        $sound.Play()
    }
}

# DEFINITION: Start everything.
Function Start-Everything(){
    while($true){
        Clear-Host
        Write-Host "     Hallo bei Flos Ueberwachungskamera-Skript v2.6!     `r`n" -ForegroundColor DarkCyan -BackgroundColor Gray
        if((Get-UserValues) -eq $false){
            Start-Sound(0)
            Start-Sleep -Seconds 2
            if($script:paraGUI -ne 0){
                $script:Form.WindowState ='Normal'
            }
            break
        }
        if((Test-UserPaths) -eq $false){
            Start-Sound(0)
            Start-Sleep -Seconds 2
            if($script:paraGUI -ne 0){
                $script:Form.WindowState ='Normal'
            }
            break
        }
        Invoke-Pause
        if($script:paraRememberIn -ne 0 -or $script:paraRememberOut -ne 0 -or $script:paraRememberPara -ne 0){
            Start-Remembering
            Invoke-Pause
        }
        $script:secondattempt = 0
        "0" | Out-File -FilePath $PSScriptRoot\fertig.txt -Encoding utf8
        if((Test-Path -Path $PSScriptRoot\preventsleep.ps1) -eq $true){
            if($script:paraShutdown -eq 0 -or ($script:paraShutdown -eq 1 -and $script:paraMeth -eq 2)){$shutdown = 0}else{$shutdown = 1}
            Start-Process powershell -ArgumentList "$PSScriptRoot\preventsleep.ps1 -fileToCheck `"$PSScriptRoot\fertig.txt`" -mode 0 -userProcessCount 2 -userProcess `"ffmpeg`",`"robocopy`" -timeBase 300 -shutdown $shutdown -counterMax 10" -WindowStyle Minimized
        }else{
            Write-Host "Kann .\preventsleep.ps1 nicht finden, daher kann Standby nicht verhindert werden." -ForegroundColor Magenta
            Start-Sleep -Seconds 3
        }

        if($script:paraMeth -eq 0){
            [array]$meldung = "Arbeitsschritte: Kopieren -> Umbenennen -> Kodieren"
        }elseif($script:paraMeth -eq 1){
            [array]$meldung = "Arbeitsschritte: Umbenennen -> Kodieren"
        }elseif($script:paraMeth -eq 2){
            [array]$meldung = "Arbeitsschritte: Loeschabfrage"
        }
        if($script:paraShutdown -eq 1 -and $script:paraMeth -le 1){
            $meldung += "PC wird nach Beendigung heruntergefahren."
        }Else{
            $meldung += "PC wird nach Beendigung nicht heruntergefahren."
        }
        Write-Host $meldung[0] -NoNewline -ForegroundColor Yellow; Write-Host " - $($meldung[1])" -ForegroundColor Cyan
        
        if($script:paraMeth -eq 0){
            Start-FileSearchAndCheck
            Invoke-Pause
            Start-FileCopy
            Invoke-Pause
            Start-FileVerification
            Invoke-Pause
        }
        if($script:paraMeth -lt 2){
            Start-KodiererBurnin
            Invoke-Pause
            Start-KodiererConcat
            Invoke-Pause
            Start-KodiererQuad
            Invoke-Pause
            Start-Loesch(0)
            Invoke-Pause
        }else{
            Start-Loesch(0)
            Invoke-Pause
        }
        Write-Host "`r`n$(Get-Date -Format "dd.MM.yy HH:mm:ss")" -NoNewline; Write-Host " - PROGRAMM FERTIG!" -ForegroundColor DarkCyan
        Start-Sound(1)
        Start-Sleep -Seconds 2
        "1" | Out-File -FilePath $PSScriptRoot\fertig.txt -Encoding utf8
        Break
    }
}

#===============================================================================
#===============================================================================
# Programming the buttons:
#===============================================================================

if($paraGUI -ne 0){
    $WPFbuttonStart.Add_Click({
        $Form.WindowState = 'Minimized'
        Start-Everything
        $Form.WindowState ='Normal'
    })

    $WPFbuttonSearchIn.Add_Click({
        Get-Folder("input")
    })

    $WPFbuttonSearchOut.Add_Click({
        Get-Folder("output")
    })

    $WPFbuttonProg.Add_Click({
        Start-Process powershell -ArgumentList "$PSScriptRoot\flo_split_quadscreen.ps1"
    })

    $WPFbuttonClose.Add_Click({
        Invoke-Close
    })
}

#===============================================================================
#===============================================================================
# Show/Start the GUI: 
#===============================================================================

if($paraGUI -ne 0){
    $Form.ShowDialog() | out-null
}else{
    Start-Everything
    Invoke-Close
}
