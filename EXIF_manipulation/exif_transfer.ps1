#requires -version 3

<#
    .SYNOPSIS
        Changes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.
    .DESCRIPTION
        Uses exiftool by Phil Harvey (https://sno.phy.queensu.ca/~phil/exiftool/)
    .NOTES
        Version:        2.1
        Author:         flolilo
        Creation Date:  2018-02-22

    .INPUTS
        files.
    .OUTPUTS
        the same files.

    .PARAMETER InputPath
        Path where images should be searched and edited (default: current path of console).
    .PARAMETER Filter
        Filter for files. E.g. "*IMG_*" for all files with IMG_ in their name.
    .PARAMETER ShowValues
        Show copyright-values before adding them.
    .PARAMETER EXIFtool
        Path to Exiftool.exe.
    .PARAMETER Debug
        Add a bit of verbose information about variables.

    .EXAMPLE
        exif_transfer -Filter "*image_525*" -EXIFtool "C:\exiftool.exe"
#>
param(
    [array]$InputPath =     @("$((Get-Location).Path)"),
    [string]$Filter =       "*",
    [int]$ShowValues =      0,
    [string]$EXIFtool =     "$($PSScriptRoot)\exiftool.exe",
    [int]$Debug =           0
)

# DEFINITION: Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding


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
            Date: 2017-10-30
        
        .PARAMETER Object
            String to write out. Mandatory, but will take every non-parametised value.
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.
        .PARAMETER Indentation
            Will move the cursor n blocks to the right, creating a possibility to indent the output without using "    " or "`t".

        .EXAMPLE
            Just use it like Write-Host.
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

# DEFINITION: Start equivalent to PreventSleep.ps1:
Function Invoke-PreventSleep(){
    <#
        .NOTES
            v1.0 - 2018-02-22
    #>
    Write-ColorOut "$(Get-CurrentDate)  --  Starting preventsleep-script..." -ForegroundColor Cyan

$standby = @'
    Write-Host "(PID = $("{0:D8}" -f $pid))" -ForegroundColor Gray
    $MyShell = New-Object -ComObject "Wscript.Shell"
    while($true){
        $MyShell.sendkeys("{F15}")
        Start-Sleep -Seconds 90
    }
'@
    $standby = [System.Text.Encoding]::Unicode.GetBytes($standby)
    $standby = [Convert]::ToBase64String($standby)

    [int]$preventstandbyid = (Start-Process powershell -ArgumentList "-EncodedCommand $standby" -WindowStyle Hidden -PassThru).Id
    if($script:Debug -gt 0){
        Write-ColorOut "preventsleep-PID is $("{0:D8}" -f $preventstandbyid)" -ForegroundColor Gray -BackgroundColor DarkGray -Indentation 4
    }
    Start-Sleep -Milliseconds 25
    if((Get-Process -Id $preventstandbyid -ErrorVariable SilentlyContinue).count -ne 1){
        Write-ColorOut "Cannot prevent standby" -ForegroundColor Magenta -Indentation 4
        Start-Sleep -Seconds 3
    }

    return $preventstandbyid
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

# DEFINITION: Get user-values:
Function Test-UserValues(){
    Write-ColorOut "$(Get-CurrentDate)  --  Testing exiftool..." -ForegroundColor Cyan

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
    if((Test-Path -LiteralPath $script:InputPath -PathType Container) -eq $false){
        Write-ColorOut "$script:InputPath not found - aborting!" -ForegroundColor Red -Indentation 2
        Start-Sound -Success 0
        Start-Sleep -Seconds 5
        return $false
    }

    return $true
}

# DEFINITION: Get user-values:
Function Get-InputFiles(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$InputPath,
        [Parameter(Mandatory=$true)]
        [string]$Filter
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Getting files..." -ForegroundColor Cyan

    [array]$original = @()
    [array]$jpg = @()
    [array]$WorkingFiles = @(Get-ChildItem -Path $script:InputPath -Filter $Filter -File | ForEach-Object {
        [PSCustomObject]@{
            BaseName = $_.BaseName
            FullName = $_.FullName
        }
    })

    [array]$WorkingFiles = @($WorkingFiles | Group-Object -Property BaseName | Where-Object {$_.Count -gt 1})

    for($i=0; $i -lt $WorkingFiles.Length; $i++){
        if($WorkingFiles[$i].Group.FullName.Length -gt 2){
            [array]$inter = @($WorkingFiles[$i].Group.FullName | Where-Object {$_ -notmatch ".jpg" -and $_ -notmatch ".jpeg"})

            Write-ColorOut "More than one source-file found. Please choose between:" -ForegroundColor Yellow -Indentation 2
            for($k=0; $k -lt $inter.Length; $k++){
                Write-ColorOut "$k - $($inter[$k])" -ForegroundColor Gray -Indentation 4
            }
            [int]$choice = 999
            while($choice -notin (0..$inter.Length)){
                try{
                    Write-ColorOut "Which one do you want?`t" -ForegroundColor Yellow -NoNewLine -Indentation 2
                    [int]$choice = Read-Host
                }catch{
                    Write-ColorOut "Wrong input!" -ForegroundColor Red -Indentation 4
                    continue
                }
            }
            $original += @($inter[$choice])
        }else{
            $original += @($WorkingFiles[$i].Group.FullName | Where-Object {$_ -notmatch ".jpg" -and $_ -notmatch ".jpeg"})
        }
        $jpg += @($WorkingFiles[$i].Group.FullName | Where-Object {$_ -match ".jpg" -or $_ -match ".jpeg"})
    }

    for($i=0; $i -lt $original.Length; $i++){
        Write-ColorOut "From:`t$($original[$i].Replace("$script:InputPath","."))" -ForegroundColor Gray -Indentation 4
        Write-ColorOut "To:`t`t  $($jpg[$i].Replace("$script:InputPath","."))" -Indentation 4
    }

    [array]$WorkingFiles = @()
    for($i=0; $i -lt $original.Length; $i++){
        $WorkingFiles += [PSCustomObject]@{
            SourceFullName = $original[$i]
            JPEGFullName = $jpg[$i]
        }
    }

    return $WorkingFiles
}

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
            Write-Progress -Activity "Transfering metadata..." -Status "File # $i - $($WorkingFiles[$i].jpg)" -PercentComplete $($i * 100 / $WorkingFiles.length)
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
        Write-ColorOut "$($WorkingFiles[$i].JPEGFullName.Replace("$script:InputPath",".")):`t" -ForegroundColor Gray -NoNewLine -Indentation 2
        if($outputerror[$i].Length -gt 0){
            Write-ColorOut "$($outputerror[$i])`t" -ForegroundColor Red -NoNewline
        }
        Write-ColorOut "$($outputout[$i])" -ForegroundColor Yellow
    }

    Write-Progress -Activity "Transfering metadata..." -Status "Done!" -Completed
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-ColorOut "                                              A" -BackgroundColor DarkGray -ForegroundColor DarkGray
    Write-ColorOut "         flolilo's EXIF transfer tool          " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "               v2.1 - 2018-02-22               " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "(PID = $("{0:D8}" -f $pid))                               `r`n" -ForegroundColor Gray -BackgroundColor DarkGray

    [int]$preventstandbyid = Invoke-PreventSleep
    if((Test-UserValues) -eq $false){
        Invoke-Pause
        Exit
    }
    Invoke-Pause

    [array]$WorkingFiles = @(Get-InputFiles -InputPath $script:InputPath -Filter $script:Filter)
    if($WorkingFiles.Length -lt 1){
        Write-ColorOut "No files found!" -ForegroundColor Magenta
        Start-Sound -Success 1
        Start-Sleep -Seconds 5
        Invoke-Pause
        Exit
    }
    Write-ColorOut "Continue?`t" -ForegroundColor Yellow -NoNewLine -Indentation 2
    Pause

    Start-Transfer -WorkingFiles $WorkingFiles -EXIFtool $script:EXIFtool

    Stop-Process -Id $preventstandbyid -Verbose

    Write-ColorOut "$(Get-CurrentDate)  --  Done!" -ForegroundColor Green
    Start-Sound -Success 1
    Start-Sleep -Seconds 5
    Invoke-Pause
}

Start-Everything
