#requires -version 3
#requires -module PoshRSJob

<#
    .SYNOPSIS

    .DESCRIPTION

    .NOTES
#>
param(
    [string]$Encoder = "C:\FFMPEG\binaries\ffmpeg.exe",
    [string]$GUI_direct = "GUI",
    [string]$InPath = "",
    [int]$FileType = 0,
    [array]$TimeFrom = @("0","0","0"),
    [array]$TimeTo = @("0","0","0"),
    [array]$SelectCam = @("0","0","0","0"),
    [int]$UseHardware = 0,
    [int]$debug = 1
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
    if($script:GUI_direct -eq "GUI"){
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
Function Get-Folder(){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $folderdialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderdialog.rootfolder = "MyComputer"
    if($folderdialog.ShowDialog() -eq "OK"){
        $script:WPFtextBoxInput.Text = $folderdialog.SelectedPath
    }
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-Host "Welcome to flolilo's quadscreen-splitter v1.5!`r`n" -ForegroundColor DarkCyan -BackgroundColor Gray

    Start-RSJob -Name "PreventStandby" -Throttle 1 -ScriptBlock {
        while($true){
            $MyShell = New-Object -com "Wscript.Shell"
            $MyShell.sendkeys("{F15}")
            Start-Sleep -Seconds 300
        }
    } | Out-Null

    # DEFINITION: testing paths:
    if((Test-Path -Path $script:InPath -PathType Leaf) -eq $false){
        Write-ColorOut "File $script:InPath not found!" -ForegroundColor Red
        Invoke-Close
    }
    if((Test-Path -Path $script:Encoder -PathType Leaf) -eq $false){
        Write-ColorOut "$script:Encoder not found!" -ForegroundColor Red
        Invoke-Close
    }

    # DEFINITION: Getting file-properties:
    $separator = "_"
    $option = [System.StringSplitOptions]::RemoveEmptyEntries
    [array]$InFile = @(Get-ChildItem -Path $script:InPath -File | ForEach-Object {
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            Directory = (Split-Path -Path $_.FullName -Parent)
        }
    })
    $neuname = $InFile.BaseName.Split($separator,$option)

    $arguments_A = " -i `"$InFile.FullName`" -ss $($script:TimeFrom[0]):$($script:TimeFrom[1]):$($script:TimeFrom[2]).00 -to $($script:TimeTo[0]):$($script:TimeTo[1]):$($script:TimeTo[2]).00 -hide_banner -an -map_metadata -1"
    $encodeparam = " -c:v libx264 -preset veryslow -crf 18", " -c:v h264_qsv -preset veryslow -q 18 -look_ahead 0"
    if($script:FileType -eq 0){
        $splitparam = " -filter:v `"crop=in_w/2:in_h/2:0:0`"", " -filter:v `"crop=in_w/2:in_h/2:in_w/2:0`"", " -filter:v `"crop=in_w/2:in_h/2:0:in_h/2`"", " -filter:v `"crop=in_w/2:in_h/2:in_w/2:in_h/2`""
        for($i=0; $i -lt 4; $i++){
            if($script:SelectCam[$i] -eq $true){
                $neuname[1] = "cam$($i + 1)"
                $arguments_Z = " `"$InFile.Directory\$($neuname[1])_$($neuname[0])_split_$($script:TimeFrom[0])-$($script:TimeFrom[1])-$($script:TimeFrom[2])_$($script:TimeTo[0])-$($script:TimeTo[1])-$($script:TimeTo[2]).mkv`"" 
                if($script:UseHardware -eq 1){
                    Start-Process -FilePath $script:Encoder -ArgumentList $arguments_A, $encodeparam[$script:UseHardware], $splitparam[$i], $arguments_z -Wait
                    Start-Sleep -Milliseconds 100
                    Write-Host "Cam $($i +1) kodiert." -ForegroundColor Yellow
                }Else{
                    Start-Process -FilePath $script:Encoder -ArgumentList $arguments_A, $encodeparam[$script:UseHardware], $splitparam[$i], $arguments_z
                    Write-Host "Cam $($i +1) kodiert." -ForegroundColor Yellow
                }
            }
        }
    }Else{
        $arguments_Z = " `"$InFile.Directory\$($InFile.BaseName)_split_$($script:TimeFrom[0])-$($script:TimeFrom[1])-$($script:TimeFrom[2])_$($script:TimeTo[0])-$($script:TimeTo[1])-$($script:TimeTo[2]).mkv`"" 
        Start-Process -FilePath $script:Encoder -ArgumentList $arguments_A, $encodeparam[$script:UseHardware], $arguments_z
        Write-Host "Cam kodiert." -ForegroundColor Yellow
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 250
    }
    
    Write-Host "`r`Done!`r`n" -ForegroundColor Green

    Get-RSJob | Stop-RSJob
    Start-Sleep -Milliseconds 25
    Get-RSJob | Remove-RSJob
}


# ==================================================================================================
# ==============================================================================
#   Programming GUI & starting everything:
# ==============================================================================
# ==================================================================================================

if($GUI_direct -eq "GUI"){
    if((Test-Path -LiteralPath "$($PSScriptRoot)/split_quadscreen.xaml" -PathType Leaf)){
        $inputXML = Get-Content -Path "$($PSScriptRoot)/split_quadscreen.xaml" -Encoding UTF8
    }else{
        Write-ColorOut "Could not find $($PSScriptRoot)/split_quadscreen.xaml - GUI can therefore not start." -ForegroundColor Red
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
        Write-ColorOut "Alternatively, start this script with '-GUI_Direct `"direct`"' (w/o single-quotes) to run it via CLI (find other parameters via '-Get-Help compare_via_ffmpeg.ps1 -detailed'." -ForegroundColor Yellow
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

    # Read parameters and fill GUI-values:
    $WPFtextBoxInput.Text = $InPath
    $WPFtextBoxFromH.Text = $TimeFrom[0]
    $WPFtextBoxFromM.Text = $TimeFrom[1]
    $WPFtextBoxFromS.Text = $TimeFrom[2]
    $WPFtextBoxToH.Text = $TimeTo[0]
    $WPFtextBoxToM.Text = $TimeTo[1]
    $WPFtextBoxToS.Text = $TimeTo[2]
    $WPFcomboBoxDatei.SelectedIndex = $FileType
    $WPFcheckBoxCamA.IsChecked = $SelectCam[0]
    $WPFcheckBoxCamB.IsChecked = $SelectCam[1]
    $WPFcheckBoxCamC.IsChecked = $SelectCam[2]
    $WPFcheckBoxCamD.IsChecked = $SelectCam[3]
    $WPFcheckBoxHardware.IsChecked = $UseHardware

    # DEFINITION: Defining buttons:
    $WPFbuttonStart.Add_Click({
        $Form.WindowState = 'Minimized'

        # Write GUI-values to parameters:
        $InPath = $WPFtextBoxInput.Text
        $TimeFrom[0] = $WPFtextBoxFromH.Text
        $TimeFrom[1] = $WPFtextBoxFromM.Text
        $TimeFrom[2] = $WPFtextBoxFromS.Text
        $TimeTo[0] = $WPFtextBoxToH.Text
        $TimeTo[1] = $WPFtextBoxToM.Text
        $TimeTo[2] = $WPFtextBoxToS.Text
        $FileType = $WPFcomboBoxDatei.SelectedIndex
        $SelectCam[0] = $WPFcheckBoxCamA.IsChecked
        $SelectCam[1] = $WPFcheckBoxCamB.IsChecked
        $SelectCam[2] = $WPFcheckBoxCamC.IsChecked
        $SelectCam[3] = $WPFcheckBoxCamD.IsChecked
        $UseHardware = $(if($WPFcheckBoxHardware.IsChecked -eq $true){1}Else{0})

        Start-Everything

        $Form.WindowState = 'Normal'
    })

    $WPFbuttonSearchIn.Add_Click({Get-Folder})
    $WPFbuttonClose.Add_Click({Invoke-Close})

    $Form.ShowDialog() | Out-Null
}else{
    Start-Everything
}
