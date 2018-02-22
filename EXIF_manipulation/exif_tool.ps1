#requires -version 3

<#
    .SYNOPSIS
        Changes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.
    .DESCRIPTION
        Uses exiftool by Phil Harvey (https://sno.phy.queensu.ca/~phil/exiftool/)
    .NOTES
        Version:        2.2
        Author:         flolilo
        Creation Date:  2018-02-22

    .INPUTS
        (optional) exif_tool_vars.json, formatted in UTF8 for copyright-values (if not provided via parameters),
        files.
    .OUTPUTS
        the same files.

    .PARAMETER InputPath
        Path where images should be searched and edited (default: current path of console). Or file(s).
    .PARAMETER Formats
        All formats to process, e.g. @("*.jpg","*.tif")
    .PARAMETER DeleteAllMeta
        Deleting all metadata or just some never used ones (like software).
    .PARAMETER AddCopyright
        Enables or disables writing of copyright-information (specified with -ArtistName and -CopyrightText).
    .PARAMETER PresetName
        Name for preset that is taken from JSON. Default: "default".
    .PARAMETER ArtistName
        Name of artist. If both -ArtistName and -CopyrightText are empty (which they are by default), values will be taken from the JSON-file.
    .PARAMETER CopyrightText
        Copyright-information you want to add. If both -ArtistName and -CopyrightText are empty (which they are by default), values will be taken from the JSON-file.
    .PARAMETER EXIFtool
        Path to exiftool.exe.
    .PARAMETER Debug
        Add a bit of verbose information about variables.

    .EXAMPLE
        exif_tool -AddCopyright 1 -ArtistName "John Doe" -CopyrightText "2017, by John Doe." -EXIFtool "C:\exiftool.exe"
#>
param(
    [array]$InputPath =         @("$((Get-Location).Path)"),
    [array]$Formats =           @("*.jpeg","*.jpg"),
    [ValidateRange(0,1)]
    [int]$DeleteAllMeta =       0,
    [ValidateRange(0,1)]
    [int]$AddCopyright =        0,
    [string]$PresetName =       "default",
    [string]$ArtistName =       "",
    [string]$CopyrightText =    "",
    [string]$EXIFtool =          "$($PSScriptRoot)\exiftool.exe",
    [int]$Debug =               0
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
    return $true
}

Function Get-InputFiles(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$InputPath,
        [Parameter(Mandatory=$true)]
        [array]$Formats
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Getting files..." -ForegroundColor Cyan
    $sw = [diagnostics.stopwatch]::StartNew()

    [array]$WorkingFiles = @()
    for($i=0; $i -lt $InputPath.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Id 1 -Activity "Searching files..." -Status "$InputPath" -PercentComplete $($($i + 1) *100 / $($InputPath.Length))
            Write-Progress -id 3 -Activity "Searching files..." -Status "File #$($WorkingFiles.Length)" -PercentComplete -1
            $sw.Reset()
            $sw.Start()
        }

        $InputPath[$i] = Resolve-Path $InputPath[$i] | Select-Object -ExpandProperty Path
        if((Test-Path -LiteralPath $InputPath[$i] -PathType Container) -eq $true){
            foreach($k in $Formats){
                if($sw.Elapsed.TotalMilliseconds -ge 750){
                    Write-Progress -Id 2 -Activity "Searching files..." -Status "Format #$($k +1)/$($Formats.Length)" -PercentComplete $($($k + 1) *100 / $($Formats.Length))
                    Write-Progress -id 3 -Activity "Searching files..." -Status "File #$($WorkingFiles.Length)" -PercentComplete -1
                    $sw.Reset()
                    $sw.Start()
                }

                $WorkingFiles += @(Get-ChildItem -LiteralPath $InputPath[$i] -Filter $k | Select-Object -ExpandProperty FullName)
            }
        }elseif((Test-Path -LiteralPath $InputPath[$i] -PathType Leaf) -eq $true){
            if($sw.Elapsed.TotalMilliseconds -ge 750){
                Write-Progress -id 3 -Activity "Searching files..." -Status "File #$($WorkingFiles.Length)" -PercentComplete -1
                $sw.Reset()
                $sw.Start()
            }

            $WorkingFiles += $InputPath[$i]
        }else{
            Write-ColorOut "$($InputPath[$i]) not found - aborting!" -ForegroundColor Red -Indentation 2
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

Function Get-EXIFValues(){
    Write-ColorOut "$(Get-CurrentDate)  --  Getting user-values..." -ForegroundColor Cyan

    if($script:ArtistName.Length -lt 1 -or $script:CopyrightText.Length -lt 1){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\exif_tool_vars.json" -PathType Leaf) -eq $true){
            try{
                $JSON = Get-Content -LiteralPath "$($PSScriptRoot)\exif_tool_vars.json" -Raw -Encoding UTF8 | ConvertFrom-JSON
                if($script:PresetName.Length -gt 0 -and $script:PresetName -in $JSON.preset){
                    $JSON = $JSON | Where-Object {$_.preset -eq $script:PresetName}
                }else{
                    Write-ColorOut "Could not find preset `"$script:PresetName`" - changed to `"default`"." -ForegroundColor Magenta -Indentation 4
                    $JSON = $JSON | Where-Object {$_.preset -eq "default"}
                }
                $JSON = $JSON.values
    
                [string]$script:ArtistName = $JSON.artist_name
                [string]$script:CopyrightText = $JSON.copyright_text
            }catch{
                Write-ColorOut "Could not load $($PSScriptRoot)\exif_tool_vars.json" -ForegroundColor Magenta -Indentation 2
                try{
                    Write-ColorOut "Enter artist name here:`t" -NoNewLine -Indentation 4
                    [string]$script:ArtistName = Read-Host
                }catch{
                    continue
                }
                try{
                    Write-ColorOut "Enter copyright text here:`t" -NoNewLine -Indentation 4
                    [string]$script:CopyrightText = Read-Host
                }catch{
                    continue
                }
            }
        }else{
            try{
                Write-ColorOut "Enter artist name here:`t" -NoNewLine -Indentation 4
                [string]$script:ArtistName = Read-Host
            }catch{
                continue
            }
            try{
                Write-ColorOut "Enter copyright text here:`t" -NoNewLine -Indentation 4
                [string]$script:CopyrightText = Read-Host
            }catch{
                continue
            }
        }
    }
}

# DEFINITION: Changing EXIF:
Function Set-Arguments(){
    # CREDIT: https://sno.phy.queensu.ca/~phil/exiftool/TagNames/EXIF.html
    # CREDIT: https://sno.phy.queensu.ca/~phil/exiftool/TagNames/IPTC.html
    Write-ColorOut "$(Get-CurrentDate)  -" -NoNewLine -ForegroundColor Cyan

    # DEFINITION: Write Arguments into string:
    if($script:DeleteAllMeta -eq 1 -and $script:AddCopyright -eq 1){
        Write-ColorOut "-  Remove all metadata, then re-add pre-existing keyword and overwrite copyright notes..." -ForegroundColor Cyan
        [string]$ArgumentList = "-All:All=`n-xresolution=300`n-yresolution=300`n-artist=$script:ArtistName`n-copyright=$script:CopyrightText`n-IPTC:By-Line=$script:ArtistName`n-IPTC:CopyrightNotice=$script:CopyrightText`n-IPTC:ObjectName<IPTC:ObjectName`n-IPTC:Keywords<IPTC:Keywords"
    }
    elseif($script:DeleteAllMeta -eq 1 -and $script:AddCopyright -eq 0){
        Write-ColorOut "-  Remove all metadata, then re-add pre-existing keywords and copyright notes..." -ForegroundColor Cyan
        [string]$ArgumentList = "-All:All=`n-xresolution=300`n-yresolution=300`n-IPTC:By-Line<IPTC:By-Line`n-IPTC:CopyrightNotice<IPTC:CopyrightNotice`n-IPTC:ObjectName<IPTC:ObjectName`n-IPTC:Keywords<IPTC:Keywords"
    }
    elseif($script:DeleteAllMeta -eq 0 -and $script:AddCopyright -eq 1){
        Write-ColorOut "-  Remove software information only, then overwrite copyright in EXIF and IPTC..." -ForegroundColor Cyan
        [string]$ArgumentList = "-xresolution=300`n-yresolution=300`n-EXIF:Software=`n-Photoshop:All=`n-Adobe:All=`n-artist=$script:ArtistName`n-copyright=$script:CopyrightText`n-IPTC:By-Line=$script:ArtistName`n-IPTC:CopyrightNotice=$script:CopyrightText`n-IPTC:ObjectName<IPTC:ObjectName`n-IPTC:Keywords<IPTC:Keywords"
    }
    elseif($script:DeleteAllMeta -eq 0 -and $script:AddCopyright -eq 0){
        Write-ColorOut "-  Remove software information only, then re-add pre-existing keywords..." -ForegroundColor Cyan
        [string]$ArgumentList = "-xresolution=300`n-yresolution=300`n-EXIF:Software=`n-Photoshop:All=`n-Adobe:All=`n-IPTC:By-Line<IPTC:By-Line`n-IPTC:CopyrightNotice<IPTC:CopyrightNotice`n-IPTC:ObjectName<IPTC:ObjectName`n-IPTC:Keywords<IPTC:Keywords"
    }
    # Keep modified date, show progress, overwrite original files, process JP(E)Gs:
    [string]$ArgumentList = $ArgumentList + "`n-P`n-overwrite_original"

    return $ArgumentList
}

# DEFINITION: Start EXIFtool:
Function Start-EXIFtool(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$WorkingFiles,
        [Parameter(Mandatory=$true)]
        [string]$ArgumentList,
        [Parameter(Mandatory=$true)]
        [string]$EXIFtool
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Start EXIFtool..." -ForegroundColor Cyan
    $sw = [diagnostics.stopwatch]::StartNew()

    # DEFINITION: Create Exiftool process:
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $EXIFtool
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
            Write-Progress -Activity "EXIFtool" -Status "#$($i + 1) - $($WorkingFiles[$i])" -PercentComplete $($($i + 1) * 100 / $WorkingFiles.Length)
            $sw.Reset()
            $sw.Start()
        }

        $exiftoolproc.StandardInput.WriteLine("$ArgumentList`n$($WorkingFiles[$i])`n-execute`n")
    }
    $exiftoolproc.StandardInput.WriteLine("-stay_open`nFalse`n")

    [array]$outputerror = @($exiftoolproc.StandardError.ReadToEnd().Split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries))
    [string]$outputout = $exiftoolproc.StandardOutput.ReadToEnd()
    $outputout = $outputout -replace '========\ ','' -replace '\[1/1]','' -replace '\ \r\n\ \ \ \ '," - " -replace '{ready}\r\n',''
    [array]$outputout = @($outputout.Split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries))

    $exiftoolproc.WaitForExit()
    Write-Progress -Activity "EXIFtool" -Status "Complete!" -Completed

    for($i=0; $i -lt $WorkingFiles.length; $i++){
        Write-ColorOut "$($WorkingFiles[$i]):`t" -ForegroundColor Gray -NoNewLine -Indentation 2
        if($outputerror[$i].Length -gt 0){
            Write-ColorOut "$($outputerror[$i])`t" -ForegroundColor Red -NoNewline
        }
        Write-ColorOut "$($outputout[$i])" -ForegroundColor Yellow
    }
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-ColorOut "                                  A" -BackgroundColor DarkGray -ForegroundColor DarkGray
    Write-ColorOut "        flolilo's EXIF-tool        " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "         v2.2 - 2018-02-22         " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "(PID = $("{0:D8}" -f $pid))                   `r`n" -ForegroundColor Gray -BackgroundColor DarkGray

    [int]$preventstandbyid = Invoke-PreventSleep
    if((Test-UserValues) -eq $false){
        Invoke-Pause
        Exit
    }else{
        Invoke-Pause
        $WorkingFiles = @(Get-InputFiles -InputPath $script:InputPath -Formats $script:Formats)
        if($WorkingFiles -eq $false){
            Invoke-Pause
            Exit
        }else{
            Invoke-Pause
        }
    }

    # DEFINITION: Get EXIF-values from JSON / user:
    if($script:AddCopyright -eq 1){
        Get-EXIFValues
        Invoke-Pause
    }

    $ArgumentList = Set-Arguments

    if($script:Debug -gt 0){
        Write-ColorOut "InputPath:`t`t$script:InputPath" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "WorkingFiles:`t$WorkingFiles" -ForegroundColor Gray -Indentation 4
        Write-ColorOut "DeleteAllMeta:`t$script:DeleteAllMeta" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "AddCopyright:`t$script:AddCopyright" -ForegroundColor Gray -Indentation 4
        Write-ColorOut "PresetName:`t`t$script:PresetName" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "ArtistName:`t`t$script:ArtistName" -ForegroundColor Gray -Indentation 4
        Write-ColorOut "CopyrightText:`t$script:CopyrightText" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "ArgumentList:`t$($ArgumentList.replace("`n"," "))" -ForegroundColor Gray -Indentation 4
        Write-ColorOut "Encoder:`t`t$script:EXIFtool" -ForegroundColor DarkGray -Indentation 4
        Pause
    }

    Start-EXIFtool -WorkingFiles $WorkingFiles -ArgumentList $ArgumentList -EXIFtool $script:EXIFtool

    Stop-Process -Id $preventstandbyid -Verbose

    Write-ColorOut "$(Get-CurrentDate)  --  Done!`r`n" -ForegroundColor Green
    Start-Sound -Success 1
    Start-Sleep -Seconds 1
    Invoke-Pause
}

Start-Everything
