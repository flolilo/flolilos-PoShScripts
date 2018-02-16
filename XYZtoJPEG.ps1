#requires -version 3

<#
    .SYNOPSIS
        Tool to convert images to JPEGs - and transfering their metadata.
    .DESCRIPTION
        This tool uses ImageMagick and ExifTool.
    .NOTES
        Version:    2.0
        Date:       2018-02-16
        Author:     flolilo

    .INPUTS
        Files.
    .OUTPUTS
        Files.

    .PARAMETER InputPath
        Path to convert files from. Or file(s).
    .PARAMETER Formats
        All formats to process.
    .PARAMETER Quality
        JPEG quality. See ImageMagick's CLI options for that.
    .PARAMETER RemoveTIF
        1 enables, 0 disables.
        Remove TIFs to Recycle Bin after conversion.
    .PARAMETER EXIFtool
        Path to exiftool.exe.
    .PARAMETER Magick
        Path to magick.exe.
    .PARAMETER ThreadCount
        Thread-Count for conversion and metadata-copying. Valid range: 1-48.
    .PARAMETER Debug
        Stops after each step.
#>
param(
    [array]$InputPath =         @("$((Get-Location).Path)"),
    [array]$Formats =           @("*.tif"),
    [ValidateRange(0,100)]
    [int]$Quality =             92,
    [ValidateRange(0,1)]
    [int]$RemoveSource =        1,
    [ValidateRange(0,1)]
    [int]$ConvertToSRGB =       0,
    [string]$EXIFtool =         "$($PSScriptRoot)\exiftool.exe",
    [string]$Magick =           "$($PSScriptRoot)\ImageMagick\magick.exe",
    [ValidateRange(1,48)]
    [int]$ThreadCount =         12,
    [int]$Debug =               0
)

# DEFINITION: Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding

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

# DEFINITION: Pause in Debug:
Function Invoke-Pause(){
    if($script:Debug -ne 0){
        Pause
    }
}

# DEFINITION: Getting date and time in pre-formatted string:
Function Get-CurrentDate(){
    return $(Get-Date -Format "yy-MM-dd HH:mm:ss")
}


# ==================================================================================================
# ==============================================================================
#    Defining specific functions:
# ==============================================================================
# ==================================================================================================

Function Test-UserValues(){
    Write-ColorOut "$(Get-CurrentDate)  --  Testing paths..." -ForegroundColor Cyan
    # DEFINITION: Search for exiftool:
    if((Test-Path -LiteralPath $script:EXIFtool -PathType Leaf) -eq $false){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\exiftool.exe" -PathType Leaf) -eq $true){
            [string]$script:EXIFtool = "$($PSScriptRoot)\exiftool.exe"
        }else{
            Write-ColorOut "Exiftool not found - aborting!" -ForegroundColor Red -Indentation 2
            Start-Sound -Success 0
            Start-Sleep -Seconds 5
            return $false
        }
    }
    if((Test-Path -LiteralPath $script:Magick -PathType Leaf) -eq $false){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\Magick.exe" -PathType Leaf) -eq $true){
            [string]$script:Magick = "$($PSScriptRoot)\Magick.exe"
        }else{
            Write-ColorOut "ImageMagick not found - aborting!" -ForegroundColor Red -Indentation 2
            Start-Sound -Success 0
            Start-Sleep -Seconds 5
            return $false
        }
    }

    return $true
}

Function Test-Duplicates(){
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
Function Get-InputFiles(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$InputPath,
        [Parameter(Mandatory=$true)]
        [array]$Formats
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Search files in InputPath(s)..." -ForegroundColor Cyan
    $sw = [diagnostics.stopwatch]::StartNew()

    [array]$WorkingFiles = @()
    for($i=0; $i -lt $InputPath.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Id 1 -Activity "Searching files..." -Status "$InputPath" -PercentComplete $($($i + 1) *100 / $($InputPath.Length))
            Write-Progress -id 3 -Activity "Searching files..." -Status "File # $($WorkingFiles.Length)" -PercentComplete -1
            $sw.Reset()
            $sw.Start()
        }

        $InputPath[$i] = Resolve-Path $InputPath[$i] | Select-Object -ExpandProperty Path
        if((Test-Path -LiteralPath $InputPath[$i] -PathType Container) -eq $true){
            foreach($k in $Formats){
                if($sw.Elapsed.TotalMilliseconds -ge 750){
                    Write-Progress -Id 2 -Activity "Searching files..." -Status "Format #$($k +1)/$($Formats.Length)" -PercentComplete $($($k + 1) *100 / $($Formats.Length))
                    Write-Progress -id 3 -Activity "Searching files..." -Status "File # $($WorkingFiles.Length)" -PercentComplete -1
                    $sw.Reset()
                    $sw.Start()
                }

                $WorkingFiles += @(Get-ChildItem -LiteralPath $InputPath[$i] -Filter $k | ForEach-Object{
                    [PSCustomObject]@{
                        SourceFullName = $_.FullName
                        SourceName = $_.Name
                        JPEGFullName = Test-Duplicates -Directory (Split-Path -Path $_.FullName -Parent) -BaseName $_.BaseName
                    }
                })
            }
        }elseif((Test-Path -LiteralPath $InputPath[$i] -PathType Leaf) -eq $true){
            $WorkingFiles += @(Get-Item -LiteralPath $InputPath[$i] | ForEach-Object {
                if($sw.Elapsed.TotalMilliseconds -ge 750){
                    Write-Progress -id 3 -Activity "Searching files..." -Status "File # $($WorkingFiles.Length)" -PercentComplete -1
                    $sw.Reset()
                    $sw.Start()
                }

                [PSCustomObject]@{
                    SourceFullName = $_.FullName
                    SourceName = $_.Name
                    JPEGFullName = Test-Duplicates -Directory (Split-Path -Path $_.FullName -Parent) -BaseName $_.BaseName
                }
            })
        }else{
            Write-ColorOut "$InputPath not found - aborting!" -ForegroundColor Red -Indentation 2
            Start-Sound -Success 0
            Start-Sleep -Seconds 5
            return $false
        }
    }
    Write-Progress -Id 3 -Activity "Searching files..." -Status "Done!" -Completed
    Write-Progress -Id 2 -Activity "Searching files..." -Status "Done!" -Completed
    Write-Progress -Id 1 -Activity "Searching files..." -Status "Done!" -Completed

    return $WorkingFiles
}

# DEFINITION: Convert:
Function Start-Converting(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$WorkingFiles,
        [Parameter(Mandatory=$true)]
        [string]$Quality,
        [Parameter(Mandatory=$true)]
        [int]$ConvertToSRGB,
        [Parameter(Mandatory=$true)]
        [string]$Magick,
        [Parameter(Mandatory=$true)]
        [int]$ThreadCount
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Converting files to JPEG..." -ForegroundColor Cyan
    $sw = [diagnostics.stopwatch]::StartNew()
    if($script:Debug -gt 0){
        [string]$debuginter = "$((Get-Location).Path)"
    }

    $WorkingFiles | ForEach-Object -Begin {
        [int]$counter = @(Get-Process -Name magick -ErrorAction SilentlyContinue).count
        [int]$i = 1
        Write-Progress -Activity "Converting files to JPEG (-q = $Quality)..." -Status "File #$i - $($_.SourceName)" -PercentComplete $($i * 100 / $WorkingFiles.Count)
        $sw.Reset()
        $sw.Start()
    } -Process {
        while($counter -ge $ThreadCount){
            $counter = @(Get-Process -Name magick -ErrorAction SilentlyContinue).count
            Start-Sleep -Milliseconds 25
        }
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Converting files to JPEG (-q = $Quality)..." -Status "File #$i - $($_.SourceName)" -PercentComplete $($i * 100 / $WorkingFiles.Length) 
            $sw.Reset()
            $sw.Start()
        }
        # TODO: "-layers merge" for layered images
        [string]$ArgList = "convert -quality $Quality -depth 8 `"$($_.SourceFullName)`""
        if($ConvertToSRGB -eq 1){
            $ArgList += " -profile `"C:\Windows\System32\spool\drivers\color\sRGB Color Space Profile.icm`" -colorspace sRGB"
        }
        $ArgList += " -quiet `"$($_.JPEGFullName)`""

        if($script:Debug -gt 0){
            Write-ColorOut $ArgList.Replace("$debuginter",".") -ForegroundColor Gray -Indentation 4
        }

        Start-Process -FilePath $Magick -ArgumentList $ArgList -NoNewWindow

        $counter++
        $i++
    } -End {
        while($counter -gt 0){
            $counter = @(Get-Process -Name magick -ErrorAction SilentlyContinue).count
            Start-Sleep -Milliseconds 10
        }
        Write-Progress -Activity "Converting files to JPEG (-q = $Quality)..." -Status "Done!" -Completed
    }
}

# DEFINITION: Transfer:
Function Start-Transfer(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$WorkingFiles,
        [Parameter(Mandatory=$true)]
        [string]$EXIFtool
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Transfering metadata..." -ForegroundColor Cyan
    $sw = [diagnostics.stopwatch]::StartNew()
    if($script:Debug -gt 0){
        [string]$debuginter = "$((Get-Location).Path)"
    }

    # DEFINITION: Create Exiftool process:
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:EXIFtool
    $psi.Arguments = "-stay_open True -@ -"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $exiftoolproc = [System.Diagnostics.Process]::Start($psi)
    Start-Sleep -Seconds 1

    # DEFINITION: Pass arguments to Exiftool:
    for($i=0; $i -lt $WorkingFiles.length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Transfering metadata..." -Status "File # $i - $($WorkingFiles[$i].SourceName)" -PercentComplete $($i * 100 / $WorkingFiles.length)
            $sw.Reset()
            $sw.Start()
        }

        [string]$ArgList = "-tagsfromfile`n$($WorkingFiles[$i].SourceFullName)`n-All:All`n-xresolution=300`n-yresolution=300`n-overwrite_original`n-progress`n$($WorkingFiles[$i].JPEGFullName)"
        if($script:Debug -gt 0){
            Write-ColorOut $ArgList.Replace("`n"," ").Replace("$debuginter",".") -ForegroundColor DarkGray -Indentation 4
        }
        $exiftoolproc.StandardInput.WriteLine("$ArgList`n-execute`n")
    }
    $exiftoolproc.StandardInput.WriteLine("-stay_open`nFalse`n")

    [array]$outputerror = @($exiftoolproc.StandardError.ReadToEnd().Split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries))
    [string]$outputout = $exiftoolproc.StandardOutput.ReadToEnd()
    $outputout = $outputout -replace '========\ ','' -replace '\[1/1]','' -replace '\ \r\n\ \ \ \ '," - " -replace '{ready}\r\n',''
    [array]$outputout = @($outputout.Split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries))

    $exiftoolproc.WaitForExit()
    Write-Progress -Activity "Transfering metadata..." -Status "Complete!" -Completed

    for($i=0; $i -lt $WorkingFiles.length; $i++){
        Write-ColorOut "$($WorkingFiles[$i].SourceName):`t" -ForegroundColor Gray -NoNewLine
        if($outputerror[$i].Length -gt 0){
            Write-ColorOut "$($outputerror[$i])`t" -ForegroundColor Red -NoNewline
        }
        Write-ColorOut "$($outputout[$i])" -ForegroundColor Yellow
    }
}

# DEFINITION: Recycle:
Function Start-Recycling(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$WorkingFiles
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Recycling source-files..." -ForegroundColor Cyan
    $sw = [diagnostics.stopwatch]::StartNew()
    if($script:Debug -gt 0){
        [string]$debuginter = "$((Get-Location).Path)"
    }

    $WorkingFiles | ForEach-Object -Begin {
        [int]$i = 1
        Write-Progress -Activity "Recycling source-files..." -Status "File #$i - $($_.SourceName)" -PercentComplete $($i * 100 / $WorkingFiles.Length)
        $sw.Reset()
        $sw.Start()
    } -Process {
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Recycling source-files..." -Status "File #$i - $($_.SourceName)" -PercentComplete $($i * 100 / $WorkingFiles.Length)
            $sw.Reset()
            $sw.Start()
        }

        if($script:Debug -gt 0){
            Write-ColorOut "Remove-ItemSafely `"$($_.SourceFullName.Replace("$debuginter","."))`"" -ForegroundColor Gray -Indentation 4
        }
        Remove-ItemSafely $_.SourceFullName
        $i++
    } -End {
        Write-Progress -Activity "Recycling source-files..." -Status "Done!" -Completed
    }
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-ColorOut "                                              A" -BackgroundColor DarkGray -ForegroundColor DarkGray
    Write-ColorOut "        flolilo's XYZ to JPEG converter        " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "               v2.0 - 2018-02-16               " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "(PID = $("{0:D8}" -f $pid))                               `r`n" -ForegroundColor Gray -BackgroundColor DarkGray

    if((Test-UserValues) -eq $false){
        Invoke-Pause
        Exit
    }else{
        Invoke-Pause
        $WorkingFiles = Get-InputFiles -InputPath $script:InputPath -Formats $script:Formats
        if($WorkingFiles -eq $false){
            Invoke-Pause
            Exit
        }else{
            Invoke-Pause
        }
    }

    Start-Converting -WorkingFiles $WorkingFiles -Quality $script:Quality -ConvertToSRGB $script:ConvertToSRGB -Magick $script:Magick -ThreadCount $script:ThreadCount
    Invoke-Pause

    Start-Transfer -WorkingFiles $WorkingFiles -EXIFtool $script:EXIFtool
    Invoke-Pause

    if($RemoveSource -eq 1){
        Start-Recycling -WorkingFiles $WorkingFiles
        Invoke-Pause
    }

    Write-ColorOut "$(Get-CurrentDate)  --  Done!" -ForegroundColor Green
    Start-Sound -Success 1
    Start-Sleep -Seconds 5
    Invoke-Pause
}

Start-Everything
