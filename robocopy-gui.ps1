#requires -version 3
#requires -module PoshRSJob

<#
    .SYNOPSIS
        Copy (and verify) user-defined filetypes from A to B.
    .DESCRIPTION
        Uses Windows' Robocopy file-copy.
    .NOTES
        Version:        0.1 (Beta)
        Author:         flolilo
        Creation Date:  2017-09-19
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT:"-tags to find them.

    .PARAMETER GUI_CLI_Direct
        Sets the mode in which the script will guide the user.
        Valid options:
            "GUI" - Graphical User Interface (default)
            "direct" - instant execution with given parameters.
    .PARAMETER InputPath
        Path from which files will be copied.
    .PARAMETER OutputPath
        Path to copy the files to.
    .PARAMETER PreventStandby
        Valid range: 0 (deactivate), 1 (activate)
        If enabled, automatic standby or shutdown is prevented as long as media-copytool is running.
    .PARAMETER ThreadCount
        Thread-count for Robocopy's /MT-switch. Recommended: 2, Valid: 1-48.
    .PARAMETER RememberInPath
        Valid range: 0 (deactivate), 1 (activate)
        If enabled, it remembers the value of -InputPath for future script-executions.
    .PARAMETER RememberOutPath
        Valid range: 0 (deactivate), 1 (activate)
        If enabled, it remembers the value of -OutputPath for future script-executions.
    .PARAMETER RememberSettings
        Valid range: 0 (deactivate), 1 (activate)
        If enabled, it remembers all parameters (excl. '-Remember*', '-showparams', and '-*Path') for future script-executions.
    .PARAMETER Debug
        Gives more verbose so one can see what is happening (and where it goes wrong).
        Valid options:
            0 - no debug (default)
            1 - only stop on end, show information
            2 - pause after every function, option to show files and their status
            3 - ???

    .INPUTS
        robocopy-gui_GUI.xaml if -GUI_CLI_direct is "GUI"
        robocopy-gui_preventsleep.ps1 if -PreventStandby is 1
        File(s) must be located in the script's directory and must not be renamed.
    .OUTPUTS
        None.

    .EXAMPLE:
        robocopy-gui.ps1
#>
param(
    [string]$GUI_CLI_Direct="GUI",
    [string]$InputPath="G:\",
    [string]$OutputPath="D:\",
    [int]$PreventStandby=1,
    [int]$ThreadCount=2,
    [int]$RememberInPath=0,
    [int]$RememberOutPath=0,
    [int]$RememberSettings=0,
    [int]$Debug=0
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

# DEFINITION: Set default ErrorAction to Stop: CREDIT: https://stackoverflow.com/a/21260623/8013879
if($Debug -eq 0){
    $PSDefaultParameterValues = @{}
    $PSDefaultParameterValues += @{'*:ErrorAction' = 'Stop'}
    $ErrorActionPreference = 'Stop'
}else{
    Write-ColorOut "PID = $($pid)" -ForegroundColor Magenta -BackgroundColor DarkGray
}

# DEFINITION: Some relevant variables from the start:
# First line of "param" (for remembering/restoring parameters):
[int]$paramline = 59
# If you want to see the variables (buttons, checkboxes, ...) the GUI has to offer, set this to 1:
[int]$getWPF = 0
# Creating it here for Invoke-Close:
[int]$preventstandbyid = 999999999


# ==================================================================================================
# ==============================================================================
#   Defining Functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Pause the programme if debug-var is active. Also, enable measuring times per command with -debug 3.
Function Invoke-Pause(){
    param($TotTime=0.0)

    if($script:Debug -gt 0 -and $TotTime -ne 0.0){
        Write-ColorOut "Used time for process:`t$TotTime" -ForegroundColor Magenta
    }
    if($script:Debug -gt 1){
        if($TotTime -ne 0.0){
            $script:timer.Reset()
        }
        Pause
        if($TotTime -ne 0.0){
            $script:timer.Start()
        }
    }
}

# DEFINITION: Exit the program (and close all windows) + option to pause before exiting.
Function Invoke-Close(){
    if($script:PreventStandby -eq 1 -and $script:preventstandbyid -ne 999999999){
        Stop-Process -Id $script:preventstandbyid -ErrorAction SilentlyContinue
    }
    if($script:Debug -gt 0){
        Pause
    }
    Exit
}

# DEFINITION: For the auditory experience:
Function Start-Sound($Success){
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
    try{
        $sound = New-Object System.Media.SoundPlayer -ErrorAction stop
        if($Success -eq 1){
            $sound.SoundLocation = "C:\Windows\Media\tada.wav"
        }else{
            $sound.SoundLocation = "C:\Windows\Media\chimes.wav"
        }
        $sound.Play()
    }catch{
        Write-Host "`a"
    }
}


# DEFINITION: "Select"-Window for buttons to choose a path.
Function Get-Folder($InOut){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $folderdialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderdialog.rootfolder = "MyComputer"
    if($folderdialog.ShowDialog() -eq "OK"){
        if($InOut -eq "input"){
            $script:WPFtextBoxInput.Text = $folderdialog.SelectedPath
        }elseif($InOut -eq "output"){
            $script:WPFtextBoxOutput.Text = $folderdialog.SelectedPath
        }
    }
}

# DEFINITION: Get values from GUI, then check the main input- and outputfolder:
Function Get-UserValues(){
    Write-ColorOut "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  --  Getting user-values..." -ForeGroundColor Cyan
    
    # get values, test paths:
    if($script:GUI_CLI_Direct -eq "GUI" -or $script:GUI_CLI_Direct -eq "direct"){
        if($script:GUI_CLI_Direct -eq "GUI"){
            # $InputPath
            $script:InputPath = $script:WPFtextBoxInput.Text
            # $OutputPath
            $script:OutputPath = $script:WPFtextBoxOutput.Text
            # $PreventStandby
            $script:PreventStandby = $(
                if($script:WPFcheckBoxPreventStandby.IsChecked -eq $true){1}
                else{0}
            )
            # $ThreadCount
            $script:ThreadCount = $script:WPFtextBoxThreadCount.Text
            # $RememberInPath
            $script:RememberInPath = $(
                if($script:WPFcheckBoxRememberIn.IsChecked -eq $true){1}
                else{0}
            )
            # $RememberOutPath
            $script:RememberOutPath = $(
                if($script:WPFcheckBoxRememberOut.IsChecked -eq $true){1}
                else{0}
            )
            # $RememberSettings
            $script:RememberSettings = $(
                if($script:WPFcheckBoxRememberSettings.IsChecked -eq $true){1}
                else{0}
            )
        }elseif($script:GUI_CLI_Direct -eq "direct"){
            # $PreventStandby
            if($script:PreventStandby -notin (0..1)){
                Write-ColorOut "Invalid choice of -PreventStandby." -ForegroundColor Red -Indentation 4
                return $false
            }
            # $ThreadCount
            if($script:ThreadCount -notin (1..48)){
                Write-ColorOut "Invalid choice of -ThreadCount." -ForegroundColor Red -Indentation 4
                return $false
            }
            # $RememberInPath
            if($script:RememberInPath -notin (0..1)){
                Write-ColorOut "Invalid choice of -RememberInPath." -ForegroundColor Red -Indentation 4
                return $false
            }
            # $RememberOutPath
            if($script:RememberOutPath -notin (0..1)){
                Write-ColorOut "Invalid choice of -RememberOutPath." -ForegroundColor Red -Indentation 4
                return $false
            }
            # $RememberSettings
            if($script:RememberSettings -notin (0..1)){
                Write-ColorOut "Invalid choice of -RememberSettings." -ForegroundColor Red -Indentation 4
                return $false
            }
        }


        # $InputPath
        if($script:InputPath.Length -lt 2 -or (Test-Path -LiteralPath $script:InputPath -PathType Container) -eq $false){
            Write-ColorOut "`r`nInput-path $script:InputPath could not be found.`r`n" -ForegroundColor Red -Indentation 4
            return $false
        }
        # $OutputPath
        if($script:OutputPath -eq $script:InputPath){
            Write-ColorOut "`r`nOutput-path is the same as input-path.`r`n" -ForegroundColor Red -Indentation 4
            return $false
        }
        if($script:OutputPath.Length -lt 2 -or (Test-Path -LiteralPath $script:OutputPath -PathType Container) -eq $false){
            if((Split-Path -Parent -Path $script:OutputPath).Length -gt 1 -and (Test-Path -LiteralPath $(Split-Path -Qualifier -Path $script:OutputPath) -PathType Container) -eq $true){
                try{
                    New-Item -ItemType Directory -Path $script:OutputPath -ErrorAction Stop | Out-Null
                    Write-ColorOut "Output-path $script:OutputPath created." -ForegroundColor Yellow -Indentation 4
                }catch{
                    Write-ColorOut "Could not create output-path $script:OutputPath." -ForegroundColor Red -Indentation 4
                    return $false
                }
            }else{
                Write-ColorOut "`r`nOutput-path not found.`r`n" -ForegroundColor Red -Indentation 4
                return $false
            }
        }

    }else{
        Write-ColorOut "Invalid choice of -GUI_CLI_Direct." -ForegroundColor Magenta -Indentation 4
        return $false
    }

    # check paths for trailing backslash:
    if($script:InputPath.Length -gt 3 -and $script:InputPath.replace($script:InputPath.Substring(0,$script:InputPath.Length-1),"") -eq "\"){
        $script:InputPath = $script:InputPath.Substring(0,$script:InputPath.Length-1)
    }
    if($script:OutputPath.Length -gt 3 -and $script:OutputPath.replace($script:OutputPath.Substring(0,$script:OutputPath.Length-1),"") -eq "\"){
        $script:OutputPath = $script:OutputPath.Substring(0,$script:OutputPath.Length-1)
    }

    if($script:Debug -gt 0){
        Write-ColorOut "InputPath:`t`t$script:InputPath" -Indentation 4
        Write-ColorOut "OutputPath:`t`t$script:OutputPath" -Indentation 4
        Write-ColorOut "PreventStandby:`t`t$script:PreventStandby" -Indentation 4
        Write-ColorOut "ThreadCount:`t`t$script:ThreadCount" -Indentation 4
    }

    # if everything was sucessful, return true:
    return $true
}

# DEFINITION: If checked, remember values for future use:
Function Start-Remembering(){
    Write-ColorOut "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  --  Remembering settings..." -ForegroundColor Cyan

    $lines_old = [System.IO.File]::ReadAllLines($PSCommandPath)
    $lines_new = $lines_old
    
    # $InputPath
    if($script:RememberInPath -gt 0){
        Write-ColorOut "From:`t$($lines_new[$($script:paramline + 1)])" -ForegroundColor Gray -Indentation 4
        $lines_new[$($script:paramline + 1)] = '    [string]$InputPath="' + "$script:InputPath" + '",'
        Write-ColorOut "To:`t$($lines_new[$($script:paramline + 1)])" -ForegroundColor Yellow -Indentation 4
    }
    # $OutputPath
    if($script:RememberOutPath -gt 0){
        Write-ColorOut "From:`t$($lines_new[$($script:paramline + 2)])" -ForegroundColor Gray -Indentation 4
        $lines_new[$($script:paramline + 2)] = '    [string]$OutputPath="' + "$script:OutputPath" + '",'
        Write-ColorOut "To:`t$($lines_new[$($script:paramline + 2)])" -ForegroundColor Yellow -Indentation 4
    }

    # Remember settings
    if($script:RememberSettings -ne 0){
        Write-ColorOut "From:" -Indentation 4
        for($i = $($script:paramline + 3); $i -le $($script:paramline + 4); $i++){
            Write-ColorOut "$($lines_new[$i])" -ForegroundColor Gray -Indentation 4
        }

        # $PreventStandby
        $lines_new[$($script:paramline + 3)] = '    [int]$PreventStandby=' + "$script:PreventStandby" + ','
        # $ThreadCount
        $lines_new[$($script:paramline + 4)] = '    [int]$ThreadCount=' + "$script:ThreadCount" + ','

        Write-ColorOut "To:" -Indentation 4
        for($i = $($script:paramline + 3); $i -le $($script:paramline + 4); $i++){
            Write-ColorOut "$($lines_new[$i])" -ForegroundColor Yellow -Indentation 4
        }
    }

    Invoke-Pause
    [System.IO.File]::WriteAllLines($PSCommandPath, $lines_new)
}

# DEFINITION: Copy Files:
Function Start-FileCopy(){
    Write-ColorOut "$(Get-Date -Format "dd.MM.yy HH:mm:ss")  --  Copy files from $InPath to $OutPath..." -ForegroundColor Cyan

    # setting up robocopy:
    [string]$rc_command = "`"$script:InputPath`" `"$script:OutputPath`" /R:5 /W:15 /MT:$script:ThreadCount /XO /XC /XN /NJH /NC /J"
    Start-Process robocopy -ArgumentList $rc_command -Wait -NoNewWindow

    Start-Sleep -Milliseconds 250
}

# DEFINITION: Starts all the things.
Function Start-Everything(){
    Write-ColorOut "`r`n`Robocopy-GUI v0.1" -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  --  Starting everything..." -ForegroundColor Cyan
    $script:timer = [diagnostics.stopwatch]::StartNew()
    while($true){
        if((Get-UserValues) -eq $false){
            Start-Sound(0)
            Start-Sleep -Seconds 2
            if($script:GUI_CLI_Direct -eq "GUI"){
                Start-GUI
            }
            break
        }
        Invoke-Pause -TotTime $script:timer.elapsed.TotalSeconds
        iF($script:RememberInPath -ne 0 -or $script:RememberOutPath -ne 0 -or $script:RememberSettings -ne 0){
            $script:timer.start()
            Start-Remembering
            Invoke-Pause -TotTime $script:timer.elapsed.TotalSeconds
        }
        if($script:PreventStandby -eq 1){
            if((Test-Path -Path "$($PSScriptRoot)\media_copytool_preventsleep.ps1" -PathType Leaf) -eq $true){
                $script:preventstandbyid = (Start-Process powershell -ArgumentList "$($PSScriptRoot)\media_copytool_preventsleep.ps1" -WindowStyle Hidden -PassThru).Id
                if($script:Debug -gt 0){
                    Write-ColorOut "preventsleep-ID is $script:preventstandbyid" -ForegroundColor Magenta -BackgroundColor DarkGray
                }
            }else{
                Write-Host "Couldn't find .\media_copytool_preventsleep.ps1, so can't prevent standby." -ForegroundColor Magenta
                Start-Sleep -Seconds 3
            }
            Invoke-Pause -TotTime $script:timer.elapsed.TotalSeconds
        }
        Start-FileCopy
        Invoke-Pause -TotTime $script:timer.elapsed.TotalSeconds
        break
    }

    $differences = @(Compare-Object -ReferenceObject $(Get-ChildItem -LiteralPath $script:InputPath -Recurse | Select-Object -ExpandProperty Name, Length) -DifferenceObject $(Get-ChildItem -LiteralPath $script:OutputPath -Recurse | Select-Object -ExpandProperty Name, Length) -ErrorAction SilentlyContinue).Count
    
    Write-ColorOut "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  --  Done!" -ForegroundColor Cyan
    Write-ColorOut "$differences differenes found." -ForegroundColor Yellow -Indentation 4
    Write-ColorOut "                                                                                `r`n" -BackgroundColor Gray
    if($differences -eq 0){
        Start-Sound(1)
    }else{
        Start-Sound(0)
    }
    
    if($script:PreventStandby -eq 1){
        Stop-Process -Id $script:preventstandbyid
    }
    if($script:GUI_CLI_Direct -eq "GUI"){
        Start-GUI
    }
}


# ==================================================================================================
# ==============================================================================
#   Programming GUI & starting everything:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Load and Start GUI:
Function Start-GUI(){
    <# CREDIT:
        code of this section (except from small modifications) by
        https://foxdeploy.com/series/learning-gui-toolmaking-series/
    #>
    if((Test-Path -LiteralPath "$($PSScriptRoot)/media_copytool_GUI.xaml" -PathType Leaf)){
        $inputXML = Get-Content -LiteralPath "$($PSScriptRoot)/media_copytool_GUI.xaml" -Encoding UTF8
    }else{
        Write-ColorOut "Could not find $($PSScriptRoot)/media_copytool_GUI.xaml - GUI can therefore not start." -ForegroundColor Red
        Pause
        Exit
    }

    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml]$xaml = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:Name",'Name'  -replace '^<Win.*', '<Window'
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    try{
        $script:Form = [Windows.Markup.XamlReader]::Load($reader)
    }
    catch{
        Write-ColorOut "Unable to load Windows.Markup.XamlReader. Usually this means that you haven't installed .NET Framework. Please download and install the latest .NET Framework Web-Installer for your OS: " -ForegroundColor Red
        Write-ColorOut "https://duckduckgo.com/?q=net+framework+web+installer&t=h_&ia=web"
        Write-ColorOut "Alternatively, start this script with '-GUI_CLI_Direct `"CLI`"' (w/o single-quotes) to run it via CLI (find other parameters via '-showparams 1' '-Get-Help media_copytool.ps1 -detailed'." -ForegroundColor Yellow
        Pause
        Exit
    }
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        Set-Variable -Name "WPF$($_.Name)" -Value $script:Form.FindName($_.Name) -Scope Script
    }

    if($getWPF -ne 0){
        Write-ColorOut "Found the following interactable elements:`r`n" -ForegroundColor Cyan
        Get-Variable WPF*
        Pause
        Exit
    }

    # Fill the TextBoxes and buttons with user parameters:
    $script:WPFtextBoxInput.Text = $script:InputPath
    $script:WPFtextBoxOutput.Text = $script:OutputPath
    $script:WPFcheckBoxMirror.IsChecked = $script:MirrorEnable
    $script:WPFtextBoxMirror.Text = $script:MirrorPath
    $script:WPFcheckBoxCan.IsChecked = $(if("Can" -in $script:PresetFormats){$true}else{$false})
    $script:WPFcheckBoxNik.IsChecked = $(if("Nik" -in $script:PresetFormats){$true}else{$false})
    $script:WPFcheckBoxSon.IsChecked = $(if("Son" -in $script:PresetFormats){$true}else{$false})
    $script:WPFcheckBoxJpg.IsChecked = $(if("Jpg" -in $script:PresetFormats -or "Jpeg" -in $script:PresetFormats){$true}else{$false})
    $script:WPFcheckBoxMov.IsChecked = $(if("Mov" -in $script:PresetFormats){$true}else{$false})
    $script:WPFcheckBoxAud.IsChecked = $(if("Aud" -in $script:PresetFormats){$true}else{$false})
    $script:WPFcheckBoxCustom.IsChecked = $script:CustomFormatsEnable
    $script:WPFtextBoxCustom.Text = $script:CustomFormats -join ","
    $script:WPFcomboBoxOutSubStyle.SelectedIndex = $(
        if("none" -eq $script:OutputSubfolderStyle){0}
        elseif("unchanged" -eq $script:OutputSubfolderStyle){1}
        elseif("yyyy-mm-dd" -eq $script:OutputSubfolderStyle){2}
        elseif("yyyy_mm_dd" -eq $script:OutputSubfolderStyle){3}
        elseif("yyyy.mm.dd" -eq $script:OutputSubfolderStyle){4}
        elseif("yyyymmdd" -eq $script:OutputSubfolderStyle){5}
        elseif("yy-mm-dd" -eq $script:OutputSubfolderStyle){6}
        elseif("yy_mm_dd" -eq $script:OutputSubfolderStyle){7}
        elseif("yy.mm.dd" -eq $script:OutputSubfolderStyle){8}
        elseif("yymmdd" -eq $script:OutputSubfolderStyle){9}
    )
    $script:WPFcomboBoxOutFileStyle.SelectedIndex = $(
        if("Unchanged" -eq $script:OutputFileStyle){0}
        elseif("yyyy-MM-dd_HH-mm-ss" -eq $script:OutputFileStyle){1}
        elseif("yyyyMMdd_HHmmss" -eq $script:OutputFileStyle){2}
        elseif("yyyyMMddHHmmss" -eq $script:OutputFileStyle){3}
        elseif("yy-MM-dd_HH-mm-ss" -eq $script:OutputFileStyle){4}
        elseif("yyMMdd_HHmmss" -eq $script:OutputFileStyle){5}
        elseif("yyMMddHHmmss" -eq $script:OutputFileStyle){6}
        elseif("HH-mm-ss" -eq $script:OutputFileStyle){7}
        elseif("HH_mm_ss" -eq $script:OutputFileStyle){8}
        elseif("HHmmss" -eq $script:OutputFileStyle){9}
    )
    $script:WPFcheckBoxUseHistFile.IsChecked = $script:UseHistFile
    $script:WPFcomboBoxWriteHistFile.SelectedIndex = $(
        if("yes" -eq $script:OutputSubfolderStyle){0}
        elseif("Overwrite" -eq $script:WriteHistFile){1}
        elseif("no" -eq $script:WriteHistFile){2}
    )
    $script:WPFcheckBoxInSubSearch.IsChecked = $script:InputSubfolderSearch
    $script:WPFcheckBoxCheckInHash.IsChecked = $script:DupliCompareHashes
    $script:WPFcheckBoxOutputDupli.IsChecked = $script:CheckOutputDupli
    $script:WPFcheckBoxVerifyCopies.IsChecked = $script:VerifyCopies
    $script:WPFcheckBoxAvoidIdenticalFiles.IsChecked = $script:AvoidIdenticalFiles
    $script:WPFcheckBoxZipMirror.IsChecked = $script:ZipMirror
    $script:WPFcheckBoxUnmountInputDrive.IsChecked = $script:UnmountInputDrive
    $script:WPFcheckBoxPreventStandby.IsChecked = $script:PreventStandby
    $script:WPFtextBoxThreadCount.Text = $script:ThreadCount
    $script:WPFcheckBoxRememberIn.IsChecked = $script:RememberInPath
    $script:WPFcheckBoxRememberOut.IsChecked = $script:RememberOutPath
    $script:WPFcheckBoxRememberMirror.IsChecked = $script:RememberMirrorPath
    $script:WPFcheckBoxRememberSettings.IsChecked = $script:RememberSettings

    # DEFINITION: InPath-Button
    $script:WPFbuttonSearchIn.Add_Click({
        Get-Folder("input")
    })
    # DEFINITION: OutPath-Button
    $script:WPFbuttonSearchOut.Add_Click({
        Get-Folder("output")
    })
    # DEFINITION: MirrorPath-Button
    $script:WPFbuttonSearchMirror.Add_Click({
        Get-Folder("mirror")
    })
    # DEFINITION: Start-Button
    $script:WPFbuttonStart.Add_Click({
        $script:Form.Close()
        Start-Everything
    })
    # DEFINITION: About-Button
    $script:WPFbuttonAbout.Add_Click({
        Start-Process powershell -ArgumentList "Get-Help $($PSCommandPath) -detailed" -NoNewWindow -Wait
    })
    # DEFINITION: Close-Button
    $script:WPFbuttonClose.Add_Click({
        $script:Form.Close()
        Invoke-Close
    })

    # DEFINITION: Start GUI
    $script:Form.ShowDialog() | Out-Null
}

if($GUI_CLI_Direct -eq "GUI"){
    Start-GUI
}else{
    Start-Everything
}
