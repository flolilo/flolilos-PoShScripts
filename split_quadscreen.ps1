#requires -version 3

param(
    [string]$encoder = "C:\FFMPEG\binaries\ffmpeg.exe",
    [string]$GUI_direct = "GUI"
)

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

# Checking if PoshRSJob is installed:
if (-not (Get-Module -ListAvailable -Name PoshRSJob)){
    Write-ColorOut "Module RSJob (https://github.com/proxb/PoshRSJob) is required, but it seemingly isn't installed - please start PowerShell as administrator and run`t" -ForegroundColor Red
    Write-ColorOut "Install-Module -Name PoshRSJob " -ForegroundColor DarkYellow
    Write-ColorOut "or use the fork of media-copytool without RSJob." -ForegroundColor Red
    Pause
    Exit
}

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

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

#                     $encoder             $userCam         $userFileFull       $userFileName       $userFilePath       $userFrom         $userTo         $userfiletype     $userhardware
Function Flo-Splitter($FloSplitterEncoder, $FloSplitterCam, $FloSplitterInFull, $FloSplitterInName, $FloSplitterInPath, $FloSplitterFrom, $FloSplitterTo, $FloSplitterMeth, $FloSplitterHardware){
    $separator = "_"
    $option = [System.StringSplitOptions]::RemoveEmptyEntries
    $neuname = $FloSplitterInName.Split($separator,$option)
    $arguments_A = " -i `"$FloSplitterInFull`" -ss $($FloSplitterFrom[0]):$($FloSplitterFrom[1]):$($FloSplitterFrom[2]).00 -to $($FloSplitterTo[0]):$($FloSplitterTo[1]):$($FloSplitterTo[2]).00 -hide_banner -an -map_metadata -1"
    $encodeparam = " -c:v libx264 -preset veryslow -crf 18", " -c:v h264_qsv -preset veryslow -q 18 -look_ahead 0"
    if($FloSplitterMeth -eq 0){
        $splitparam = " -filter:v `"crop=in_w/2:in_h/2:0:0`"", " -filter:v `"crop=in_w/2:in_h/2:in_w/2:0`"", " -filter:v `"crop=in_w/2:in_h/2:0:in_h/2`"", " -filter:v `"crop=in_w/2:in_h/2:in_w/2:in_h/2`""
        for($i=0; $i -lt 4; $i++){
            if($FloSplitterCam[$i] -eq $true){
                $neuname[1] = "cam$($i + 1)"
                $arguments_Z = " `"$FloSplitterInPath\$($neuname[1])_$($neuname[0])_split_$($FloSplitterFrom[0])-$($FloSplitterFrom[1])-$($FloSplitterFrom[2])_$($FloSplitterTo[0])-$($FloSplitterTo[1])-$($FloSplitterTo[2]).mkv`"" 
                if($FloSplitterHardware -eq 1){
                    Start-Process -FilePath $FloSplitterEncoder -ArgumentList $arguments_A, $encodeparam[$FloSplitterHardware], $splitparam[$i], $arguments_z -Wait
                    Start-Sleep -Milliseconds 100
                    Write-Host "Cam $($i +1) kodiert." -ForegroundColor Yellow
                }Else{
                    Start-Process -FilePath $FloSplitterEncoder -ArgumentList $arguments_A, $encodeparam[$FloSplitterHardware], $splitparam[$i], $arguments_z
                    Write-Host "Cam $($i +1) kodiert." -ForegroundColor Yellow
                }
            }
        }
    }Else{
        $arguments_Z = " `"$FloSplitterInPath\$($FloSplitterInName)_split_$($FloSplitterFrom[0])-$($FloSplitterFrom[1])-$($FloSplitterFrom[2])_$($FloSplitterTo[0])-$($FloSplitterTo[1])-$($FloSplitterTo[2]).mkv`"" 
        Start-Process -FilePath $FloSplitterEncoder -ArgumentList $arguments_A, $encodeparam[$FloSplitterHardware], $arguments_z
        Write-Host "Cam kodiert." -ForegroundColor Yellow
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 250
    }
    Write-Host " "
    Write-Host "Fertig!" -ForegroundColor Green
    Write-Host " "
}

Function Start-Everything(){
    Write-Host "Welcome to flolilo's quadscreen-splitter v1.5!`r`n" -ForegroundColor DarkCyan -BackgroundColor Gray
    Start-RSJob -Name "PreventStandby" -Throttle 1 -ScriptBlock {
        while($true){
            $MyShell = New-Object -com "Wscript.Shell"
            $MyShell.sendkeys("{F15}")
            Start-Sleep -Seconds 300
        }
    } | Out-Null

    Flo-Splitter $encoder $userCam $userFileFull $userFileName $userFilePath $userFrom $userTo $userfiletype $userhardware

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

    $WPFbuttonStart.Add_Click({
        $Form.WindowState = 'Minimized'

        $userInput = Get-ChildItem -Path $WPFtextBoxInput.Text -File
        $userFileFull = $userInput.FullName
        $userFileName = $userInput.BaseName
        $userFilePath = $userInput.Directory
        $userFrom = @("0","0","0")
        $userFrom[0] = $WPFtextBoxFromH.Text
        $userFrom[1] = $WPFtextBoxFromM.Text
        $userFrom[2] = $WPFtextBoxFromS.Text
        $userTo = @("0","0","0")
        $userTo[0] = $WPFtextBoxToH.Text
        $userTo[1] = $WPFtextBoxToM.Text
        $userTo[2] = $WPFtextBoxToS.Text
        $userfiletype = $WPFcomboBoxDatei.SelectedIndex
        $userCam = @("0","0","0","0")
        $userCam[0] = $WPFcheckBoxCamA.IsChecked
        $userCam[1] = $WPFcheckBoxCamB.IsChecked
        $userCam[2] = $WPFcheckBoxCamC.IsChecked
        $userCam[3] = $WPFcheckBoxCamD.IsChecked
        $userhardware = $(if($WPFcheckBoxHardware.IsChecked -eq $true){1}Else{0})

        Start-Everything

        $Form.WindowState = 'Normal'
    })
    
    $WPFbuttonSearchIn.Add_Click({
        Get-Folder
    })
    
    $WPFbuttonClose.Add_Click({
        Invoke-Close
    })
    $Form.ShowDialog() | Out-Null
}else{
    Start-Everything
}
