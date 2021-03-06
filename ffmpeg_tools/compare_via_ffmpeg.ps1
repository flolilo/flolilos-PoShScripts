#requires -version 3

<#
    .SYNOPSIS
        Will compare two videos via FFmpeg.

    .DESCRIPTION
        None at this time.

    .NOTES
        Version:        1.1
        Author:         flolilo
        Creation Date:  2017-9-8
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT:"-tags to find them.

    .PARAMETER encoder
        Set path to ffmpeg.exe

    .INPUTS
        ffmpeg.exe
        video files

    .OUTPUTS
        video file.

    .EXAMPLE
        compare-via-ffmpeg.ps1 -GUI_direct direct
#>
param(
    [string]$encoder = "C:\FFMPEG\binaries\ffmpeg.exe",
    [string]$VidInA = "",
    [string]$VidInB = "",
    [string]$VidOut = "",
    [string]$GUI_direct = "GUI",
    [int]$debug = 0
)

# DEFINITION: Get all error-outputs in English:
    [Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
    $OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding
    [Console]::InputEncoding = New-Object -TypeName System.Text.UTF8Encoding
# DEFINITION: Load PoshRSJob:
    try{
        Import-Module -Name "PoshRSJob" -NoClobber -Global -ErrorAction Stop
    }catch{
        try{
            [string]$PoshRSJobPath = Get-ChildItem -LiteralPath $PSScriptRoot\Modules\PoshRSJob -Recurse -Filter PoshRSJob.psm1 -ErrorAction Stop | Select-Object -ExpandProperty FullName
            Import-Module $PoshRSJobPath -NoClobber -Global -ErrorAction Stop
        }catch{
            Write-Host "Could not load Module `"PoshRSJob`" - Please install it in an " -ForegroundColor Red -NoNewline
            Write-Host "administrative console " -ForegroundColor Yellow -NoNewline
            Write-Host "via " -ForegroundColor Red -NoNewline
            Write-Host "Install-Module PoshRSJob" -NoNewline
            Write-Host ", download it from " -ForegroundColor Red -NoNewline
            Write-Host "github.com/proxb/PoshRSJob/releases " -NoNewline
            Write-Host "and install it to " -ForegroundColor Red -NoNewline
            Write-Host "<SCRIPT_PATH>\Modules\PoshRSJob\<VERSION.NUMBER>" -NoNewline -ForegroundColor Gray
            Write-Host "." -ForegroundColor Red
            Pause
            Exit
        }
    }

# If you want to see the variables (buttons, checkboxes, ...) the GUI has to offer, set this to 1:
[int]$getWPF = 0


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
            Date: 2018-05-22
        
        .PARAMETER Object
            String to write out
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.

        .EXAMPLE
            Just use it like Write-Host.
    #>
    param(
        [string]$Object = "Write-ColorOut was called, but no string was transfered.",

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
Function Start-Sound(){
    <#
        .SYNOPSIS
            Gives auditive feedback for fails and successes
        .DESCRIPTION
            Uses SoundPlayer and Windows's own WAVs to play sounds.
        .NOTES
            Date: 2018-03-12

        .PARAMETER Success
            1 plays Windows's "tada"-sound, 0 plays Windows's "chimes"-sound.
        
        .EXAMPLE
            For success: Start-Sound 1
        .EXAMPLE
            For fail: Start-Sound 0
    #>
    param(
        [int]$Success = $(return $false)
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


# DEFINITION: "Select"-Window for buttons to choose a path.
Function Get-Folder($VidAVidBOut){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $folderdialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderdialog.rootfolder = "MyComputer"
    if($folderdialog.ShowDialog() -eq "OK"){
        if($VidAVidBOut -eq "VidA"){
            $script:WPFtextBoxInA.Text = $folderdialog.SelectedPath
        }
        if($VidAVidBOut -eq "VidB"){
            $script:WPFtextBoxInB.Text = $folderdialog.SelectedPath
        }
        if($VidAVidBOut -eq "Out"){
            $script:WPFtextBoxOut.Text = $folderdialog.SelectedPath
        }
    }
}

Function Test-Everything(){
    [int]$counter = 0
    if((Test-Path -LiteralPath $script:encoder -PathType Leaf) -ne $true){
        Write-ColorOut "Cannot find ffmpeg.exe - aborting!" -ForegroundColor Red
        $counter++
    }

    if((Test-Path -LiteralPath $script:VidInA -PathType Leaf) -ne $true){
        Write-ColorOut "Cannot find $script:VidInA - aborting!" -ForegroundColor Red
        $counter++
    }
    if((Test-Path -LiteralPath $script:VidInB -PathType Leaf) -ne $true){
        Write-ColorOut "Cannot find $script:VidInB - aborting!" -ForegroundColor Red
        $counter++
    }

    if((Test-Path -LiteralPath $(Split-Path -LiteralPath $script:VidOut -Parent) -PathType Container) -ne $false){
        if((Test-Path -LiteralPath $(Split-Path -LiteralPath $script:VidOut -Qualifier) -PathType Container) -ne $false){
            Write-ColorOut "Invalid output-path - aborting!" -ForegroundColor Red
            $counter++
        }else{
            try{
                New-Item -LiteralPath $(Split-Path -LiteralPath $script:VidOut -Parent) -ItemType Directory
            }catch{
                Write-ColorOut "Could not create $(Split-Path -LiteralPath $script:VidOut -Parent) - aborting!" -ForegroundColor Red
                $counter++
            }
        }
    }
    if($counter -eq 0){
        return $true
    }else{
        return $false
    }
}

# DEFINITION: Start everything:
Function Start-Everything(){
    if(Test-Everything -eq $false){
        Start-Sound 0
        Invoke-Close
    }else{
        Start-RSJob -Name "PreventStandby" -Throttle 1 -ScriptBlock {
            while($true){
                $MyShell = New-Object -com "Wscript.Shell"
                $MyShell.sendkeys("{F15}")
                Start-Sleep -Seconds 300
            }
        } | Out-Null

        $ffmpeg_arguments = " -i `"$script:VidInA`" -i `"$script:VidInB`" -hide_banner -filter_complex `"[1:v]format=yuva444p,lut=c3=128,negate[video2withAlpha],[0:v][video2withAlpha]overlay[out]`" -map `"[out]`" -c:v libx264 -pix_fmt yuv444p -preset veryslow -intra -crf 10 -an -map_metadata -1 `"$script:VidOut`""
        Write-Host "FFmpeg Arguments: $ffmpeg_arguments`r`n" -ForegroundColor Yellow
        
        Start-Process -FilePath $script:encoder -ArgumentList $ffmpeg_arguments -Wait -NoNewWindow

        Get-RSJob | Stop-RSJob
        Start-Sleep -Milliseconds 25
        Get-RSJob | Remove-RSJob

        Write-ColorOut "Done!" -ForegroundColor Green
        Start-Sound 1
    }
}


# ==================================================================================================
# ==============================================================================
#   Programming GUI & starting everything:
# ==============================================================================
# ==================================================================================================

if($GUI_direct -eq "GUI"){
    if((Test-Path -LiteralPath "$($PSScriptRoot)/compare_via_ffmpeg.xaml" -PathType Leaf)){
        $inputXML = Get-Content -Path "$($PSScriptRoot)/compare_via_ffmpeg.xaml" -Encoding UTF8
    }else{
        Write-ColorOut "Could not find $($PSScriptRoot)/compare_via_ffmpeg.xaml - GUI can therefore not start." -ForegroundColor Red
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

    # Fill the TextBoxes and buttons with user parameters:
    $WPFtextBoxInA.Text = $VidInA
    $WPFtextBoxInB.Text = $VidInB
    $WPFtextBoxOut.Text = $VidOut

    # DEFINITION: Buttons:
    $WPFbuttonStart.Add_Click({
        $Form.WindowState = 'Minimized'

        $VidInA = $WPFtextBoxInA.Text
        $VidInB = $WPFtextBoxInB.Text
        $VidOut = $WPFtextBoxOut.Text

        Start-Everything

        $Form.WindowState = 'Normal'
    })
    $WPFbuttonSearchInA.Add_Click({Get-Folder("VidA")})
    $WPFbuttonSearchInB.Add_Click({Get-Folder("VidB")})
    $WPFbuttonSearchOut.Add_Click({Get-Folder("Out")})
    $WPFbuttonClose.Add_Click({
        Invoke-Close
    })

    # DEFINITION: Start GUI
    $Form.ShowDialog() | Out-Null
}else{
    Start-Everything
}