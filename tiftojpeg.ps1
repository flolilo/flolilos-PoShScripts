#requires -version 3


<#
    .SYNOPSIS
        Tool to convert TIFs to JPEGs - and including their metadata.
    .DESCRIPTION
        This tool uses ImageMagick and ExifTool.
    .NOTES
        Version:    1.1
        Date:       2017-12-13
        Author:     flolilo

    .INPUTS
        TIF-files.
    .OUTPUTS
        JPEG-files.

    .PARAMETER InputPath
        Path to convert files from.
    .PARAMETER EXIFtool
        Path to exiftool.exe.
    .PARAMETER Magick
        Path to magick.exe.
    .PARAMETER Quality
        JPEG quality. See ImageMagick's CLI options for that.
    .PARAMETER RemoveTIF
        1 enables, 0 disables.
        Remove TIFs to Recycle Bin after conversion.
    .PARAMETER ThreadCount
        Thread-Count for conversion and metadata-copying. Valid range: 1-48.
#>
param(
    [string]$InputPath =    "$((Get-Location).Path)",
    [string]$EXIFtool =     "$($PSScriptRoot)\exiftool.exe",
    [string]$Magick =       "C:\Program Files\ImageMagick-7.0.7-Q8\magick.exe",
    [ValidateRange(0,100)]
    [int]$Quality =         92,
    [ValidateRange(0,1)]
    [int]$RemoveTIF =       1,
    [ValidateRange(1,48)]
    [int]$ThreadCount =     12
)

$sw = [diagnostics.stopwatch]::StartNew()

if((Get-Module -ListAvailable -Name "Recycle") -eq $false){
    Write-Host "Module `"Recycle`" does not exist! Please install it via `"Get-Module Recycle`"." -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}


# ==================================================================================================
# ==============================================================================
#    Defining generic functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Making Write-ColorOut much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-ColorOut
        .DESCRIPTION
            Using the [Console]-commands to make everything faster.
        .NOTES
            Date: 2017-10-25
        
        .PARAMETER Object
            String to write out
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.

        .EXAMPLE
            Just use it like Write-ColorOut.
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

Function Start-JPEGtest(){
    param(
        [Parameter(Mandatory=$true)]
        [string]$Directory,
        [Parameter(Mandatory=$true)]
        [string]$BaseName
    )

    [string]$inter = "$($Directory)\$($BaseName).jpg"
    if((Test-Path -Path $inter -PathType Leaf) -eq $true){
        [int]$k = 1
        while($true){
            [string]$inter = "$($Directory)\$($BaseName)_$($k).jpg"
            if((Test-Path -Path $inter -PathType Leaf) -eq $true){
                $k++
                continue
            }else{
                [string]$result = $inter
                break
            }
        }
    }else{
        [string]$result = $inter
    }

    return $result
}

# DEFINITION: Get Files:
    Write-ColorOut "$(Get-Date -Format "dd.MM.yy HH:mm:ss")  --  Search files in $InPath..." -ForegroundColor Cyan
    [array]$files = @(Get-ChildItem -Path $InputPath -File -Filter *.tif | ForEach-Object -Begin {
        [int]$i = 1
        Write-Progress -Activity "Searching files..." -Status "File # $i" -PercentComplete -1
        $sw.Reset()
        $sw.Start()
    } -Process {
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Searching files..." -Status "File # $i" -PercentComplete -1
            $sw.Reset()
            $sw.Start()
        }
        [PSCustomObject]@{
            TIFFullName = $_.FullName
            TIFName = $_.Name
            JPEGFullName = Start-JPEGtest -Directory (Split-Path -Path $_.FullName -Parent) -BaseName $_.BaseName
        }
        $i++
    } -End {
        Write-Progress -Activity "Searching files..." -Status "Done!" -Completed        
    })

# DEFINITION: Convert:
    Write-ColorOut "$(Get-Date -Format "dd.MM.yy HH:mm:ss")  --  Converting TIF to JPEG..." -ForegroundColor Cyan
    $files | ForEach-Object -Begin {
        [int]$counter=0
        [int]$i = 1
        Write-Progress -Activity "Converting TIF to JPEG (-q = $Quality)..." -Status "File # $i/$($files.Count) - $($_.TIFName)" -PercentComplete $($i * 100 / $files.Count)
        $sw.Reset()
        $sw.Start()
    } -Process {
        while($counter -ge $ThreadCount){
            $counter = @(Get-Process -Name magick -ErrorAction SilentlyContinue).count
            Start-Sleep -Milliseconds 7
        }
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Converting TIF to JPEG (-q = $Quality)..." -Status "File # $i/$($files.Count) - $($_.TIFName)" -PercentComplete $($i * 100 / $files.Count) 
            $sw.Reset()
            $sw.Start()
        }
        # Write-ColorOut "magick convert -quality $Quality `"$($_.TIFFullName.Replace("$InputPath","."))`" `"$($_.JPEGFullName.Replace("$InputPath","."))`"" -ForegroundColor Gray -Indentation 4
        # Start-Sleep -Milliseconds 50
        Start-Process -FilePath $Magick -ArgumentList "convert -quiet -quality $Quality `"$($_.TIFFullName)`" `"$($_.JPEGFullName)`"" -NoNewWindow
        $counter++
        $i++
    } -End {
        while($counter -gt 0){
            $counter = @(Get-Process -Name magick -ErrorAction SilentlyContinue).count
            Start-Sleep -Milliseconds 10
        }
        Write-Progress -Activity "Converting TIF to JPEG (-q = $Quality)..." -Status "Done!" -Completed
    }

# DEFINITION: Transfer:
    Write-ColorOut "$(Get-Date -Format "dd.MM.yy HH:mm:ss")  --  Transfering metadata..." -ForegroundColor Cyan
    $files | ForEach-Object -Begin {
        [int]$counter=0
        [int]$i = 1
        Write-Progress -Activity "Transfering metadata..." -Status "File # $i/$($files.Count) - $($_.TIFName)" -PercentComplete $($i * 100 / $files.Count)
        $sw.Reset()
        $sw.Start()
    } -Process {
        while($counter -ge $ThreadCount){
            $counter = @(Get-Process -Name exiftool -ErrorAction SilentlyContinue).count
            Start-Sleep -Milliseconds 7
        }
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Transfering metadata..." -Status "File # $i/$($files.Count) - $($_.TIFName)" -PercentComplete $($i * 100 / $files.Count)
            $sw.Reset()
            $sw.Start()
        }
        # Write-ColorOut "exiftool -tagsfromfile `"$($_.TIFFullName.Replace("$InputPath","."))`" -All:All -overwrite_original `"$($_.JPEGFullName.Replace("$InputPath","."))`"" -ForegroundColor DarkGray -Indentation 4
        # Start-Sleep -Milliseconds 50
        Start-Process -FilePath $EXIFtool -ArgumentList " -q -tagsfromfile `"$($_.TIFFullName)`" -All:All -overwrite_original `"$($_.JPEGFullName)`"" -NoNewWindow
        $counter++
        $i++
    } -End {
        while($counter -gt 0){
            $counter = @(Get-Process -Name exiftool -ErrorAction SilentlyContinue).count
            Start-Sleep -Milliseconds 10
        }
        Write-Progress -Activity "Transfering metadata..." -Status "Done!" -Completed
    }


# DEFINITION: Recycle:
    if($RemoveTIF -eq 1){
        Write-ColorOut "$(Get-Date -Format "dd.MM.yy HH:mm:ss")  --  Recycling TIFs..." -ForegroundColor Cyan
        $files | ForEach-Object -Begin {
            [int]$i = 1
            Write-Progress -Activity "Recycling TIFs..." -Status "File # $i/$($files.Count) - $($_.TIFName)" -PercentComplete $($i * 100 / $files.Count)
            $sw.Reset()
            $sw.Start()
        } -Process {
            if($sw.Elapsed.TotalMilliseconds -ge 750){
                Write-Progress -Activity "Recycling TIFs..." -Status "File # $i/$($files.Count) - $($_.TIFName)" -PercentComplete $($i * 100 / $files.Count)
                $sw.Reset()
                $sw.Start()
            }
            # Write-ColorOut "Remove-ItemSafely `"$($_.TIFFullName)`"" -ForegroundColor Gray -Indentation 4
            # Start-Sleep -Milliseconds 50
            Remove-ItemSafely $_.TIFFullName
            $i++
        } -End {
            Write-Progress -Activity "Recycling TIFs..." -Status "Done!" -Completed
        }
    }

Write-ColorOut "$(Get-Date -Format "dd.MM.yy HH:mm:ss")  --  Done!..." -ForegroundColor Green
Start-Sound -Success 1
Start-Sleep -Seconds 5
