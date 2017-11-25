#requires -version 3

<#
    .SYNOPSIS
        Changes EXIF and IPTC information from images (especially JPEGs) and can also add a copyright to them.
    .DESCRIPTION
        Uses exiftool by Phil Harvey (https://sno.phy.queensu.ca/~phil/exiftool/)
    .NOTES
        Version:        1.8
        Author:         flolilo
        Creation Date:  2017-11-25

    .INPUTS
        exiftool.exe
        (optional) exif_tool_vars.json, formatted in UTF8 for copyright-values (if not provided via parameters).
    .OUTPUTS
        none.

    .PARAMETER InputPath
        Path where images should be searched and edited (default: current path of console).
    .PARAMETER DeleteAllEXIF
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
    .PARAMETER ShowValues
        Show copyright-values before adding them.
    .PARAMETER Debug
        Add a bit of verbose information about variables.

    .EXAMPLE
        exif_tool -AddCopyright 1 -ArtistName "John Doe" -CopyrightText "2017, by John Doe." -Encoder "C:\exiftool.exe"
#>
param(
    [string]$InputPath =        "$((Get-Location).Path)",
    [ValidateRange(0,1)]
    [int]$DeleteAllEXIF =       0,
    [ValidateRange(0,1)]
    [int]$AddCopyright =        0,
    [string]$PresetName =       "default",
    [string]$ArtistName =       "",
    [string]$CopyrightText =    "",
    [string]$Encoder =          "$($PSScriptRoot)\exiftool.exe",
    [int]$ShowValues =          0,
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
Function Get-UserValues(){
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

    # DEFINITION: Search for exiftool:
    if((Test-Path -LiteralPath $script:Encoder -PathType Leaf) -eq $false){
        if((Test-Path -LiteralPath "$($PSScriptRoot)\exiftool.exe" -PathType Leaf) -eq $false){
            Write-ColorOut "Exiftool not found - aborting!" -ForegroundColor Red -Indentation 2
            Start-Sound -Success 0
            Start-Sleep -Seconds 5
            Exit
        }else{
            [string]$script:Encoder = "$($PSScriptRoot)\exiftool.exe"
        }
    }
}

# DEFINITION: Deleting EXIF:
Function Set-EXIF(){
    # CREDIT: https://sno.phy.queensu.ca/~phil/exiftool/TagNames/EXIF.html
    # CREDIT: https://sno.phy.queensu.ca/~phil/exiftool/TagNames/IPTC.html

    Write-ColorOut "$(Get-Date -Format "yy.MM.dd - HH:mm")  -" -NoNewLine -ForegroundColor Gray
    # DEFINITION: Write Arguments into string:
    [string]$ArgumentList = ""
    if($script:DeleteAllEXIF -eq 1 -and $script:AddCopyright -eq 1){
        Write-ColorOut "-  Delete all metadata, then add Copyright to EXIF and IPTC..." -ForegroundColor Cyan
        [string]$ArgumentList = " -All:All= -artist=`"$script:ArtistName`" -copyright=`"$script:CopyrightText`" -IPTC:By-Line=`"$script:ArtistName`" -IPTC:CopyrightNotice=`"$script:CopyrightText`""
    }
    elseif($script:DeleteAllEXIF -eq 1 -and $script:AddCopyright -eq 0){
        Write-ColorOut "-  Delete all metadata..." -ForegroundColor Cyan
        [string]$ArgumentList = " -All:All= -IPTC:By-Line<IPTC:By-Line -IPTC:CopyrightNotice<IPTC:CopyrightNotice -IPTC:ObjectName<IPTC:ObjectName -IPTC:Keywords<IPTC:Keywords"
    }
    elseif($script:DeleteAllEXIF -eq 0 -and $script:AddCopyright -eq 1){
        Write-ColorOut "-  Delete only software information, overwrite copyright in EXIF and IPTC..." -ForegroundColor Cyan
        [string]$ArgumentList = " -EXIF:Software= -Photoshop:All= -Adobe:All= -artist=`"$script:ArtistName`" -copyright=`"$script:CopyrightText`" -IPTC:By-Line=`"$script:ArtistName`" -IPTC:CopyrightNotice=`"$script:CopyrightText`" -IPTC:ObjectName<IPTC:ObjectName -IPTC:Keywords<IPTC:Keywords"
    }
    elseif($script:DeleteAllEXIF -eq 0 -and $script:AddCopyright -eq 0){
        Write-ColorOut "-  Delete only software information, re-add IPTC-tags..." -ForegroundColor Cyan
        [string]$ArgumentList = " -EXIF:Software= -Photoshop:All= -Adobe:All= -IPTC:By-Line<IPTC:By-Line -IPTC:CopyrightNotice<IPTC:CopyrightNotice -IPTC:ObjectName<IPTC:ObjectName -IPTC:Keywords<IPTC:Keywords"
    }
    # Keep modified date, show progress, overwrite original files, process JP(E)Gs:
    [string]$ArgumentList = $ArgumentList + " -P -progress -overwrite_original -ext jpg -ext jpeg `"$script:InputPath\*`""
    if($script:Debug -eq 1){
        Write-ColorOut "ArgumentList:`t$ArgumentList" -ForegroundColor DarkGray -Indentation 4
        Pause
    }

    Push-Location $script:InputPath
    Start-Process -FilePath $script:Encoder -ArgumentList $ArgumentList -NoNewWindow -Wait
    Pop-Location
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-ColorOut "Welcome to flolilo's exif-tool!" -ForegroundColor DarkCyan -BackgroundColor Gray

    Get-UserValues
    if($script:AddCopyright -eq 1){
        Write-ColorOut "Artist's name:`t$script:ArtistName" -ForegroundColor Gray -Indentation 4
        Write-ColorOut "Copyright text:`t$script:CopyrightText" -ForegroundColor DarkGray -Indentation 4
        if($script:ShowValues -eq 1){
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
    if($script:Debug -eq 1){
        Write-ColorOut "InputPath:`t`t$script:InputPath" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "DeleteAllEXIF:`t$script:DeleteAllEXIF" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "AddCopyright:`t$script:AddCopyright" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "PresetName:`t`t$script:PresetName" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "ArtistName:`t`t$script:ArtistName" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "CopyrightText:`t$script:CopyrightText" -ForegroundColor DarkGray -Indentation 4
        Write-ColorOut "Encoder:`t`t$script:Encoder" -ForegroundColor DarkGray -Indentation 4
        Pause
    }
    

    if((Test-Path -LiteralPath $script:InputPath -PathType Container) -eq $true){
        Set-EXIF
        Write-ColorOut "$(Get-Date -Format "yy.MM.dd - HH:mm")  -" -NoNewLine -ForegroundColor Gray
        Write-ColorOut "-  Done!" -ForegroundColor Green
        Start-Sound -Success 1
    }else{
        Write-ColorOut "Path not found - aborting!" -ForegroundColor Red
        Start-Sound -Success 0
        Start-Sleep -Seconds 5
        Exit
    }
}

Start-Everything
