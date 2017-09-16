#requires -version 3

<#
    .SYNOPSIS
        This script will find certain containers and then analyse their codecs with the help of FFprobe.
    .DESCRIPTION
        To be done.
    .NOTES
        Version:    v1.0
        Author:     flolilo
        Date:       2017-09-16

    .INPUT
        None.
    .OUTPUT
        None.
    
    .PARAMETER FFprobe
        Path to ffprobe.exe
    .PARAMETER Encoder
        Path to ffmpeg.exe
    .PARAMETER OutPath
        Path for Textfiles.
    .PARAMETER UserInput
        Paths to search files in.
    .PARAMETER FileTypes
        File-extensions to look for.
    .PARAMETER VideoTypes
        Video-codecs that are "good"
    .PARAMETER AudioTypes
        Audio-codecs that are "good"
    .PARAMETER OverwriteJSON
        Enable/disable overwriting old/existing JSON files.
    .PARAMETER Delete_ProbeFiles
        Enable/disable deleting JSON files after finishing.
    .PARAMETER DebugFiles
        Enable/disable creating of JSON file for debugging (i.e. looking for codecs on one's own).
    .PARAMETER StartFFmpeg
        Enable/disable transcoding with FFmpeg.

    .EXAMPLE
        .\oldcodec_searchanddestroy.ps1 -UserInput "D:\MyFolder" -OutPath "E:\"
#>
param(
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$FFprobe = "C:\FFMPEG\binaries\ffprobe.exe",

    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$Encoder = "C:\FFMPEG\binaries\ffmpeg.exe",

    [ValidateScript({Test-Path -Path $_ -PathType Container})]
    [string]$OutPath = "R:\",

    [array]$UserInput = @(),
    [array]$FileTypes = @("*.avi","*.mkv","*.mp4","*.mpg","*.mov"),
    [array]$VideoTypes = @("h264","h265"),
    [array]$AudioTypes = @("opus","flac","aac"),

    [ValidateRange(0,1)]
    [int]$OverwriteJSON = 1,

    [ValidateRange(0,1)]
    [int]$Delete_ProbeFiles = 1,

    [ValidateRange(0,1)]
    [int]$DebugFiles = 1,
    
    [ValidateRange(0,1)]
    [int]$StartFFmpeg = 0
)

#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

# DEFINITION: Making Write-ColorOut much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-ColorOut
        
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


# ==================================================================================================
# ==============================================================================
#   Defining Functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Get variables if necessary:
Function Get-UserInput(){
    while($true){
        [int]$max = Read-Host "How many folders should be scanned?`t"
        if($max -notin (1..99)){
            Write-ColorOut "Invalid input!" -ForegroundColor Magenta
            Continue
        }else{
            break
        }
    }
    for($i=0; $i -lt $max; $i++){
        while($true){
            try{
                [string]$inter = (Read-Host "Folder #$($i + 1) to be scanned`t")
            }catch{
                Write-ColorOut "Invalid input!" -ForegroundColor Magenta
                Continue
            }
            if(Test-Path -Path $inter -PathType Container){
                $script:UserInput += $inter
                break
            }else{
                Write-ColorOut "Folder not found!" -ForegroundColor Magenta
                Continue
            }
        }
    }
    while($true){
        [int]$script:Delete_ProbeFiles = (Read-Host "Delete JSON-files afterward? `"1`" for `"yes`", `"0`" for `"no`"")
        if($script:Delete_ProbeFiles -notin (0..1)){
            Write-ColorOut "Invalid input!" -ForegroundColor Magenta
            Continue
        }else{
            break
        }
    }
    while($true){
        [int]$script:Debug = (Read-Host "Create debug-files?")
        if($script:Debug -notin (0..1)){
            Write-ColorOut "Invalid input!" -ForegroundColor Magenta
            Continue
        }else{
            break
        }
    }
}

# DEFINITION: Scanning for files:
Function Get-InputFiles(){
    $sw = [diagnostics.stopwatch]::StartNew()
    [array]$script:FilesIn = @()
    for($i=0; $i -lt $script:UserInput.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
            Write-Progress -Activity "Looking for files..." -Status "$($script:UserInput[$i])" -PercentComplete $($($i / $script:UserInput.Length) * 100)
            $sw.Reset()
            $sw.Start()
        }
        for($j=0; $j -lt $script:FileTypes.Length; $j++){
            $script:FilesIn += (Get-ChildItem -Path $script:UserInput[$i] -Recurse -File -Filter $script:FileTypes[$j] | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    FullNameWoExt = $_.FullName.Remove(($lastIndex = $_.FullName.LastIndexOf($_.Extension)),$_.Extension.Length).Insert($lastIndex,"")
                    Directory = (Split-Path -Parent -Path $_.FullName)
                    # approvedcodec = -1
                    # streamorder = ""
                    videostream = $null
                    videocodec = $null
                    audiostream = $null
                    audiocodec = $null
                    audiochannel = $null
                    substream = $null
                    subtype = $null
                    otherstream = $null
                    othertype = $null
                    ffmpegcode = $null
                }
            })
        }
    }
    Write-Progress -Activity "Looking for files..." -Status "Done!" -Completed

    $script:FilesIn = $script:FilesIn | Sort-Object -Property FullName
    $script:FilesIn | Out-Null
}

# DEFINITION: Running FFprobe (if enabled):
Function Start-FFprobe(){
    $sw = [diagnostics.stopwatch]::StartNew()
    [int]$processcount = 0
    for($i=0; $i -lt $script:FilesIn.Length; $i++){
        if(-not ($script:OverwriteJSON -eq 0 -and (Test-Path -Path "$($script:FilesIn[$i].FullNameWoExt).json" -PathType Leaf) -eq $true)){
            while($processcount -gt 12){
                $processcount = @(Get-Process -ErrorAction SilentlyContinue -Name ffprobe).count
                Start-Sleep -Milliseconds 25
            }
            if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
                Write-Progress -Activity "Running FFprobe..." -Status "$($script:FilesIn[$i].FullName)" -PercentComplete $($($i / $script:FilesIn.Length) * 100)
                $sw.Reset()
                $sw.Start()
            }
            Start-Process -FilePath $script:FFprobe -ArgumentList " -hide_banner -i `"$($script:FilesIn[$i].FullName)`" -print_format json -show_streams -loglevel fatal" -NoNewWindow -RedirectStandardOutput "$($script:FilesIn[$i].FullNameWoExt).json"
            $processcount++
        }
    }

    while($processcount -ne 0){
        $processcount = @(Get-Process -ErrorAction SilentlyContinue -Name ffprobe).count
        Start-Sleep -Milliseconds 75
    }
    Write-Progress -Activity "Running FFprobe..." -Status "Done!" -Completed
}

# DEFINITION: Gathering and reading JSON-files:
Function Start-Readout(){
    $sw = [diagnostics.stopwatch]::StartNew()
    for($i=0; $i -lt $script:FilesIn.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
            Write-Progress -Activity "Gathering JSON-file-information..." -Status "$($script:FilesIn[$i].FullName)" -PercentComplete $($($i / $script:FilesIn.Length) * 100)
            $sw.Reset()
            $sw.Start()
        }
        $JSONFile = Get-Content -Path "$($script:FilesIn[$i].FullNameWoExt).json" -Raw -Encoding UTF8 | ConvertFrom-Json
        $JSONFile | Out-Null
        $JSONFile = $JSONFile.streams # because there's a "streams" sub-element...
        $JSONFile | Out-Null
        $JSONFile | ForEach-Object {
            if($_.codec_type -eq "video"){
                $script:FilesIn[$i].videostream = $_.index
                $script:FilesIn[$i].videocodec = $_.codec_name
            }elseif($_.codec_type -eq "audio"){
                $script:FilesIn[$i].audiostream =  @($_.index)
                $script:FilesIn[$i].audiocodec = @($_.codec_name)
                try{
                    $script:FilesIn[$i].audiochannel = @($_.channel_layout -replace '\(side\)','')
                }catch{
                    $script:FilesIn[$i].audiochannel = @($_.channels -replace '1','mono' -replace '2','stereo')
                }
            }elseif($_.codec_type -eq "subtitle"){
                $script:FilesIn[$i].substream = @($_.index)
                $script:FilesIn[$i].subtype = @($_.codec_type)
            }else{
                $script:FilesIn[$i].otherstream = @($_.index)
                $script:FilesIn[$i].othertype = @($_.codec_type)
            }
        }
    }
    Write-Progress -Activity "Gathering JSON-file-information..." -Status "Done!" -Completed
}

# DEFINITION: Delete JSON files:
Function Start-Deletion(){
    $sw = [diagnostics.stopwatch]::StartNew()
    [int]$counter = 0
    $script:FilesIn | ForEach-Object -Process {
        if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
            Write-Progress -Activity "Deleting XML-files..." -Status "$($_.FullNameWoExt).json" -PercentComplete $($($counter / $_.Length) * 100)
            $sw.Reset()
            $sw.Start()
        }
        $counter++
        Remove-Item -Path "$($_.FullNameWoExt).json"
    } -End {Write-Progress -Activity "Deleting XML-files..." -Status "Done!" -Completed}
}

# DEFINITION: Filter bad from good files by comparing streams:
Function Start-Filtering(){
    $sw = [diagnostics.stopwatch]::StartNew()

    for($i=0; $i -lt $script:FilesIn.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
            Write-Progress -Activity "Filtering..." -Status "$($script:FilesIn[$i].FullName)" -PercentComplete $($($i / $script:FilesIn.Length) * 100)
            $sw.Reset()
            $sw.Start()
        }
        
        if($script:FilesIn[$i].videostream -ne 0 -or ($script:FilesIn[$i].audiostream -gt 0 -and $script:FilesIn[$i].audiostream -ne 1) -or $script:FilesIn[$i].videocodec -notin $script:videotypes -or $script:FilesIn[$i].audiocodec -notin $script:audiotypes){
            # $script:FilesIn[$i].approvedcodec = 0
            $script:FilesIn[$i].ffmpegcode += " -hide_banner -loglevel fatal -i `"$($script:FilesIn[$i].FullName)`""
            $script:FilesIn[$i].ffmpegcode += " -map 0:$($script:FilesIn[$i].videostream) -c:v "
            if($script:FilesIn[$i].videocodec -notin $script:videotypes){
                $script:FilesIn[$i].ffmpegcode += "libx265 -crf 16 -preset slow"
            }else{
                $script:FilesIn[$i].ffmpegcode += "copy"
            }
            if($script:FilesIn[$i].audiostream.Length -gt 0){
                for($j=0; $j -lt $script:FilesIn[$i].audiostream.Length; $j++){
                    $script:FilesIn[$i].ffmpegcode += " -map 0:$($script:FilesIn[$i].audiostream[$j]) -c:a:$j "
                    if($script:FilesIn[$i].audiocodec[$j] -notin $script:audiotypes){
                        if($script:FilesIn[$i].audiocodec[$j] -like "pcm*"){
                            $script:FilesIn[$i].ffmpegcode += "flac"
                        }else{
                            $script:FilesIn[$i].ffmpegcode += "libopus -b:a:$($script:FilesIn[$i].audiostream[$j]) "
                            if($script:FilesIn[$i].audiochannel[$j] -eq "stereo"){
                                $script:FilesIn[$i].ffmpegcode += "128k"
                            }elseif($script:FilesIn[$i].audiochannel[$j] -eq "mono"){
                                $script:FilesIn[$i].ffmpegcode += "64k"
                            }else{
                                while($true){
                                    [int]$inter = Read-Host "Plase specify bitrate for $script:FilesIn[$i].audiochannel[$j]`t"
                                    if($inter -notin (64..1408)){
                                        continue
                                    }else{
                                        break
                                    }
                                }
                                
                                $script:FilesIn[$i].ffmpegcode += "$($inter)k"
                            }
                        }
                    }else{
                        $script:FilesIn[$i].ffmpegcode += "copy"
                    }
                }
            }
            if($script:FilesIn[$i].substream.Length -gt 0){
                for($j=0; $j -lt $script:FilesIn[$i].substream.Length; $j++){
                    $script:FilesIn[$i].ffmpegcode += " -map 0:$($script:FilesIn[$i].substream[$j])"
                }
                $script:FilesIn[$i].ffmpegcode += " -c:s copy"
            }
            $script:FilesIn[$i].ffmpegcode += " `"$($script:FilesIn[$i].FullNameWoExt)_NEW.mkv`""
        }else{
            # $script:FilesIn[$i].approvedcodec = 1
        }
    }
    Write-Progress -Activity "Filtering..." -Status "Done!" -Completed
}

# Write Files to screen and/or to files:
Function Start-FileWriting(){
    $script:FilesIn | Select-Object -Property * -ExcludeProperty FullNameWoExt, Directory | Format-List

    if($script:DebugFiles -eq 1){
        $results = $script:FilesIn | Select-Object -Property * -ExcludeProperty FullNameWoExt, Directory | ConvertTo-Json
        try{
            [System.IO.File]::WriteAllText("$($script:OutPath)AllFiles.txt", $results)
        }
        catch{
            Write-ColorOut "Writing to debug-file failed! Trying again..." -ForegroundColor Red
            Pause
            Continue
        }
    }
}

# DEFINITION: here you may change the behavior of FFmpeg (i.e. encoding formats):
Function Start-FFmpeg(){
    $sw = [diagnostics.stopwatch]::StartNew()
    [int]$processcount = 0
    for($i=0; $i -lt $script:FilesIn.Length; $i++){
        while($processcount -gt 6){
            $processcount = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
            Start-Sleep -Milliseconds 25
        }
        if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
            Write-Progress -Activity "FFmpeging..." -Status "$($script:FilesIn[$i].FullName)" -PercentComplete $($($i / $script:FilesIn.Length) * 100)
            $sw.Reset()
            $sw.Start()
        }
        if($script:FilesIn[$i].ffmpegcode.Length -gt 0){
            Start-Process -FilePath $script:Encoder -ArgumentList $script:FilesIn[$i].ffmpegcode -NoNewWindow
            $processcount++
        }
    }
    while($processcount -gt 0){
        $processcount = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 75
    }
    Write-Progress -Activity "FFmpeging..." -Status "Done!" -Completed
}

# DEFINITION: Start everything:
Function Start-Everything(){
    if($script:UserInput.Length -lt 1){
        Get-UserInput
    }else{
        foreach($i in $script:UserInput){
            if((Test-Path -Path $i -PathType Container) -eq $false){
                Write-ColorOut "Could not find $i - aborting!" -ForegroundColor Red
                Start-Sleep -Seconds 5
                Exit
            }
        }
    }
    Write-ColorOut "Write Debug-Files:`t`t$script:DebugFiles" -ForegroundColor Cyan
    Write-ColorOut "Overwrite old JSON files:`t$script:OverwriteJSON" -ForegroundColor Cyan
    Write-ColorOut "Delete JSON afterwards:`t`t$script:Delete_ProbeFiles`r`n" -ForegroundColor Cyan

    Get-InputFiles
    if($script:RunFFprobe -ne 0){
        Start-FFprobe
    }
    Start-Readout
    if($script:Delete_ProbeFiles -eq 1){
        Start-Deletion
    }
    Start-Filtering
    Start-FileWriting
    if($script:StartFFmpeg -eq 1){
        Start-FFmpeg
    }
}


# ==================================================================================================
# ==============================================================================
#   Starting everything:
# ==============================================================================
# ==================================================================================================

Start-Everything
Write-ColorOut "`r`nDONE." -ForegroundColor Green
