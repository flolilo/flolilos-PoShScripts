#requires -version 3

<#
    .SYNOPSIS
        Changes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.
    .DESCRIPTION
        Uses exiftool by Phil Harvey (https://sno.phy.queensu.ca/~phil/exiftool/)
    .NOTES
        Version:        2.0
        Author:         flolilo
        Creation Date:  2018-02-16

    .INPUTS
        exiftool.exe
        (optional) exif_tool_vars.json, formatted in UTF8 for copyright-values (if not provided via parameters).
    .OUTPUTS
        none.

    .PARAMETER InputPath
        Path where images should be searched and edited (default: current path of console).
    .PARAMETER Formats
        All formats to process.
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
    .PARAMETER Encoder
        Path to exiftool.exe.
    .PARAMETER Debug
        Add a bit of verbose information about variables.

    .EXAMPLE
        exif_tool -AddCopyright 1 -ArtistName "John Doe" -CopyrightText "2017, by John Doe." -Encoder "C:\exiftool.exe"
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


# ==================================================================================================
# ==============================================================================
#    Defining specific functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Get user-values:
Function Test-UserValues(){
    Write-ColorOut "$(Get-Date -Format "yy.MM.dd - HH:mm")  -" -NoNewLine -ForegroundColor Gray
    Write-ColorOut "-  Testing paths..." -ForegroundColor Cyan

    # DEFINITION: Search for exiftool:
    if((Test-Path -LiteralPath $script:Encoder -PathType Leaf) -eq $false){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\exiftool.exe" -PathType Leaf) -eq $true){
            [string]$script:Encoder = "$($PSScriptRoot)\exiftool.exe"
        }else{
            Write-ColorOut "Exiftool not found - aborting!" -ForegroundColor Red -Indentation 2
            Start-Sound -Success 0
            Start-Sleep -Seconds 5
            return $false
        }
    }

    [array]$script:WorkingFiles = @()
    for($i=0; $i -lt $script:InputPath.Length; $i++){
        $script:InputPath[$i] = Resolve-Path $script:InputPath[$i] | Select-Object -ExpandProperty Path
        if((Test-Path -LiteralPath $script:InputPath[$i] -PathType Container) -eq $true){
            foreach($k in $script:Formats){
                $script:WorkingFiles += @(Get-ChildItem -LiteralPath $script:InputPath[$i] -Filter $k | Select-Object -ExpandProperty FullName)
            }
        }elseif((Test-Path -LiteralPath $script:InputPath[$i] -PathType Leaf) -eq $true){
                $script:WorkingFiles += $script:InputPath[$i]
        }else{
            Write-ColorOut "InputPath not found - aborting!" -ForegroundColor Red -Indentation 2
            Start-Sound -Success 0
            Start-Sleep -Seconds 5
            return $false
        }
    }

    return $true
}

Function Get-EXIFValues(){
    Write-ColorOut "$(Get-Date -Format "yy.MM.dd - HH:mm")  -" -NoNewLine -ForegroundColor Gray
    Write-ColorOut "-  Getting user-values..." -ForegroundColor Cyan
    if($script:AddCopyright -eq 1 -and ($script:ArtistName.Length -lt 1 -or $script:CopyrightText.Length -lt 1)){
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

    Write-ColorOut "$(Get-Date -Format "yy.MM.dd - HH:mm:ss")  -" -NoNewLine -ForegroundColor Gray
    # DEFINITION: Write Arguments into string:
    if($script:DeleteAllMeta -eq 1 -and $script:AddCopyright -eq 1){
        Write-ColorOut "-  Delete all metadata, then add Copyright to EXIF and IPTC..." -ForegroundColor Cyan
        [string]$ArgumentList = "-All:All=`n-xresolution=288`n-yresolution=288`n-artist=$script:ArtistName`n-copyright=$script:CopyrightText`n-IPTC:By-Line=$script:ArtistName`n-IPTC:CopyrightNotice=$script:CopyrightText"
    }
    elseif($script:DeleteAllMeta -eq 1 -and $script:AddCopyright -eq 0){
        Write-ColorOut "-  Delete all metadata..." -ForegroundColor Cyan
        [string]$ArgumentList = "-All:All=`n-xresolution=288`n-yresolution=288`n-IPTC:By-Line<IPTC:By-Line`n-IPTC:CopyrightNotice<IPTC:CopyrightNotice`n-IPTC:ObjectName<IPTC:ObjectName`n-IPTC:Keywords<IPTC:Keywords"
    }
    elseif($script:DeleteAllMeta -eq 0 -and $script:AddCopyright -eq 1){
        Write-ColorOut "-  Delete only software information, overwrite copyright in EXIF and IPTC..." -ForegroundColor Cyan
        [string]$ArgumentList = "-xresolution=288`n-yresolution=288`n-EXIF:Software=`n-Photoshop:All=`n-Adobe:All=`n-artist=$script:ArtistName`n-copyright=$script:CopyrightText`n-IPTC:By-Line=$script:ArtistName`n-IPTC:CopyrightNotice=$script:CopyrightText`n-IPTC:ObjectName<IPTC:ObjectName`n-IPTC:Keywords<IPTC:Keywords"
    }
    elseif($script:DeleteAllMeta -eq 0 -and $script:AddCopyright -eq 0){
        Write-ColorOut "-  Delete only software information, re-add IPTC-tags..." -ForegroundColor Cyan
        [string]$ArgumentList = "-xresolution=288`n-yresolution=288`n-EXIF:Software=`n-Photoshop:All=`n-Adobe:All=`n-IPTC:By-Line<IPTC:By-Line`n-IPTC:CopyrightNotice<IPTC:CopyrightNotice`n-IPTC:ObjectName<IPTC:ObjectName`n-IPTC:Keywords<IPTC:Keywords"
    }
    # Keep modified date, show progress, overwrite original files, process JP(E)Gs:
    [string]$ArgumentList = $ArgumentList + "`n-P`n-overwrite_original"
    if($script:Debug -eq 1){
        Write-ColorOut "ArgumentList:`t$($ArgumentList.replace("`n"," "))" -ForegroundColor DarkGray -Indentation 4
        Pause
    }

    return $ArgumentList
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-ColorOut "Welcome to flolilo's EXIF-tool!" -ForegroundColor DarkCyan -BackgroundColor Gray
    if((Test-UserValues) -eq $false){
        Exit
    }

    # DEFINITION: Get EXIF-values from JSON / user:
    Get-EXIFValues
    if($script:AddCopyright -eq 1){
        Write-ColorOut "Artist's name:`t$script:ArtistName" -ForegroundColor Gray -Indentation 4
        Write-ColorOut "Copyright text:`t$script:CopyrightText" -ForegroundColor DarkGray -Indentation 4
        if($script:Debug -gt 0){
            while($true){
                Write-ColorOut "To proceed, press 1:`t" -NoNewLine -ForegroundColor Yellow
                if((Read-Host) -eq 1){
                    break
                }else{
                    continue
                }
            }
        }
    }

    $ArgumentList = Set-Arguments

    if($script:Debug -gt 0){
        Write-ColorOut "InputPath:`t`t$script:InputPath" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "WorkingFiles:`t$script:WorkingFiles" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "DeleteAllMeta:`t$script:DeleteAllMeta" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "AddCopyright:`t$script:AddCopyright" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "PresetName:`t`t$script:PresetName" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "ArtistName:`t`t$script:ArtistName" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "CopyrightText:`t$script:CopyrightText" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "Encoder:`t`t$script:Encoder" -ForegroundColor DarkGray -Indentation 4
        Pause
    }

    # Create Exiftool process
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:EXIFtool
    $psi.Arguments = "-stay_open True -@ -"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $exiftoolproc = [System.Diagnostics.Process]::Start($psi)
    Start-Sleep -Seconds 1

    for($i=0; $i -lt $script:WorkingFiles.length; $i++){
        Write-Progress -Activity "ExifTool" -Status "$i" -PercentComplete $($i / $script:WorkingFiles.Length)
        $exiftoolproc.StandardInput.WriteLine("$ArgumentList`n$($script:WorkingFiles[$i])`n-execute`n")
    }
    Write-Progress -Activity "ExifTool" -Status "Complete!" -Completed
    $exiftoolproc.StandardInput.WriteLine("-stay_open`nFalse`n")

    [array]$outputerror = $exiftoolproc.StandardError.ReadToEnd()
    [array]$outputout = $exiftoolproc.StandardOutput.ReadToEnd().Split("`r`n",[System.StringSplitOptions]::RemoveEmptyEntries)
    $outputout = $outputout | Where-Object {$_ -ne "{Ready}"}

    $exiftoolproc.WaitForExit()

    Write-Host "Errors:`t$outputerror" -ForegroundColor Red
    Write-Host "Outputs:`t$outputout" -ForegroundColor Gray
}

Start-Everything
