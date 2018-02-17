#requires -version 3

# TODO: TODO: Proper documentation, Remove-ItemSafely TODO: TODO:
<#
    .SYNOPSIS
        Deletes subfolders that don't contain specified extensions. Also deletes abandoned XMPs.
    .DESCRIPTION
        Uses the Recycle module to move files to Recycle Bin.
    .NOTES
        Version:        1.3
        Author:         flolilo
        Creation Date:  2018-02-17
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT:"-tags to find them.

        .INPUTS
            None.
        .OUTPUTS
            None.

        .PARAMETER InputPath
            Path to check.
        .PARAMETER CatalogFolder
            Folder that should be excluded.
        .PARAMETER Extensions
            Extensions that are searched for: if these exist in a folder, it will not be deleted.
        .PARAMETER Debug
            Adds confirmation-dialogs for removal of folders.

        .EXAMPLE
            .\pictures_cleanup.ps1 -$script:InputPath "D:\My pictures" -catalog_Folder "dontdeleteme" -extensions @("*.ext1","*.ext2") -debug 1
#>
param(
    [string]$InputPath = "$((Get-Location).Path)",
    [string]$CatalogFolder = "_Picture_Catalogs",
    [array]$Extensions = @(
        "*.arw",
        "*.avi",
        "*.bmp",
        "*.cr2",
        "*.dng",
        "*.eip",
        "*.hdr",
        "*.j2k",
        "*.jp2",
        "*.jpeg",
        "*.jpg",
        "*.jxr",
        "*.mkv",
        "*.mov",
        "*.mp4",
        "*.nef",
        "*.nrw",
        "*.png",
        "*.pdf",
        "*.psb",
        "*.psd",
        "*.tga",
        "*.tif",
        "*.tiff"
    ),
    [int]$Debug = 1
)
[int]$confirm = $Debug

# DEFINITION: Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding
# DEFINITION: Load Module "Recycle" for moving files to bin instead of removing completely.
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

# DEFINITION: Getting date and time in pre-formatted string:
Function Get-CurrentDate(){
    return $(Get-Date -Format "yy-MM-dd HH:mm:ss")
}


# ==================================================================================================
# ==============================================================================
#    Defining specific functions:
# ==============================================================================
# ==================================================================================================

[int]$errorcounter = 0

# DEFINITION: Search for folders:
Function Start-Searching(){
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputPath,
        [Parameter(Mandatory=$true)]
        [string]$CatalogFolder,
        [Parameter(Mandatory=$true)]
        [array]$Extensions
    )
    $sw = [diagnostics.stopwatch]::StartNew()

    # DEFINITION: Look up the folders:
    [array]$WorkingFolders = @(Get-ChildItem -LiteralPath $InputPath -Directory -Recurse | Where-Object {$_.FullName -notmatch $CatalogFolder} | ForEach-Object -Begin {
        [int]$i = 1
        Write-Progress -Activity "Getting folders..." -Status "# $i - $($_.FullName)" -PercentComplete -1
            $sw.Reset()
            $sw.Start()
    } -Process {
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Getting folders..." -Status "# $i - $($_.FullName)" -PercentComplete -1
            $sw.Reset()
            $sw.Start()
        }

        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            FileCount = 0
            Directory = Split-Path -Parent -Path $_.FullName
            # SubfolderCount = (Get-ChildItem -Path $_.FullName -Directory).count
        }
        $i++
    } -End {
        Write-Progress -Activity "Getting folders..." -Status "Done" -Completed
    })

    # DEFINITION: Look up each folder's files:
    for($i=0; $i -lt $WorkingFolders.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 750 -or $i -eq 0){
            Write-Progress -Activity "Getting files..." -Status "# $i - $($WorkingFolders[$i].FullName)" -PercentComplete ($($i + 1) * 100 / $WorkingFolders.Length)
            $sw.Reset()
            $sw.Start()
        }

        foreach($j in $extensions){
            [int]$WorkingFolders[$i].FileCount += (Get-ChildItem -LiteralPath $WorkingFolders[$i].FullName -Filter $j -Recurse).Count
        }
    }
    Write-Progress -Activity "Getting files..." -Status "Done" -Completed

    $WorkingFolders = $WorkingFolders | Sort-Object -Property FullName -Descending
    $WorkingFolders | Out-Null

    return $WorkingFolders
}

# DEFINITION: Cleaning up:
Function Start-Cleaning(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$ToClean,
        [Parameter(Mandatory=$true)]
        [string]$InputPath
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Looking for folders to delete.." -ForegroundColor Cyan

    for($i=0; $i -lt $ToClean.Length; $i++){
        if($ToClean[$i].filecount -eq 0){
            Write-ColorOut "$($ToClean[$i].FullName.Replace($InputPath,"."))`t`thas $($ToClean[$i].filecount) files." -ForegroundColor DarkGray
            if($confirm -eq 1){
                $inter = Get-ChildItem -LiteralPath $ToClean[$i].FullName -File -Recurse | Sort-Object -Property Extension,BaseName
                $inter | Format-Table -AutoSize -Property BaseName,Extension,Length
            }
            if($confirm -eq 0 -or ($confirm -eq 1 -and (Read-Host "Is that okay? 1 for yes, 0 for no") -eq 1)){
                try{
                    Remove-ItemSafely -LiteralPath $ToClean[$i].FullName -Recurse -Verbose
                    # Remove-Item -LiteralPath $ToClean[$i].FullName -Recurse -Verbose
                }catch{
                    Write-ColorOut "Removing failed!" -ForegroundColor Magenta
                    $script:errorcounter++
                }
            }
        }else{
            Write-ColorOut "$($folder[$i].FullName.Replace($InputPath,"."))`t`thas $($ToClean[$i].filecount) files." -ForegroundColor DarkGreen
        }
    }
}

# DEFINITION: Search for abandoned XMPs and delete them:
Function Start-XMPcleanup(){
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputPath,
        [Parameter(Mandatory=$true)]
        [array]$WorkingFiles
    )
    Write-ColorOut "$(Get-CurrentDate)  --  Searching for abandoned XMPs and delete them..." -ForegroundColor Cyan
    $sw = [diagnostics.stopwatch]::StartNew()

    # DEFINITION: Get all XMPs:
    [array]$XMP = Get-ChildItem -Path $ToClean[$i].FullName -Filter *.xmp -Recurse | ForEach-Object -Begin {
        [int]$i = 1
        Write-Progress -Activity "Getting XMPs..." -Status "#$i - $($ToClean[$i].FullName)" -PercentComplete -1
        $sw.Reset()
        $sw.Start()
    } -Process {
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Getting XMPs..." -Status "#$i - $($ToClean[$i].FullName)" -PercentComplete -1
            $sw.Reset()
            $sw.Start()
        }
        $i++

        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            Directory = Split-Path -Parent -Path $_.FullName
        }
    } -End {
        Write-Progress -Activity "Getting XMPs..." -Status "Done" -Completed
    }

    [array]$ToClean = @()
    for($i=0; $i -lt $XMP.Length; $i++){
        if($sw.Elapsed.TotalMilliseconds -ge 750 -or $i -eq 0){
            Write-Progress -Activity "Checking XMPs..." -Status "#$($i + 1) - $($XMP[$i].FullName)" -PercentComplete $($($i + 1) * 100 / $XMP.Length)
            $sw.Reset()
            $sw.Start()
        }

        if((Compare-Object $XMP[$i] -DifferenceObject $WorkingFiles -Property BaseName,Directory -ExcludeDifferent -IncludeEqual -ErrorAction Stop).count -gt 0){
            if($script:Debug -gt 0){
                Write-ColorOut "XMP $($XMP[$i].FullName)`tis not alone." -ForegroundColor Green -Indentation 4
            }
        }else{
            Write-ColorOut "XMP $($XMP[$i].FullName)`tis abandoned!" -ForegroundColor Red -Indentation 4
            $ToClean += @($XMP[$i].FullName)
        }
    }
    Write-Progress -Activity "Checking XMPs..." -Status "Done" -Completed

    if($ToClean.Length -gt 0){
        Write-ColorOut "Abandoned XMPs found. Delete them?" -ForegroundColor Yellow -Indentation 2
        [int]$i = 999
        while($i -notin (0..1)){
            try{
                [int]$i = Read-Host
            }catch{
                continue
            }
        }
    }

    $ToClean | ForEach-Object -Begin {
        [int]$i = 1
        Write-Progress -Activity "Deleting abandoned XMPs..." -Status "#$($i + 1) - $_" -PercentComplete $($i * 100 / $ToClean.Length)
            $sw.Reset()
            $sw.Start()
    } -Process {
        if($sw.Elapsed.TotalMilliseconds -ge 750){
            Write-Progress -Activity "Deleting abandoned XMPs..." -Status "#$($i + 1) - $_" -PercentComplete $($i * 100 / $ToClean.Length)
            $sw.Reset()
            $sw.Start()
        }
        $i++

        Remove-ItemSafely -LiteralPath $_
    } -End {
        Write-Progress -Activity "Deleting abandoned XMPs..." -Status "Done" -Completed
    }
}

# DEFINITION: Start everything:
Function Start-Everything(){
    Write-ColorOut "                                              A" -BackgroundColor DarkGray -ForegroundColor DarkGray
    Write-ColorOut "           flolilo's picture-cleanup           " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "               v1.3 - 2018-02-17               " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "(PID = $("{0:D8}" -f $pid))                               `r`n" -ForegroundColor Gray -BackgroundColor DarkGray

    if((Test-Path -LiteralPath $script:InputPath -PathType Container) -eq $false){
        Write-ColorOut "Folder non-existent!" -ForegroundColor Red
        Start-Sleep -Seconds 5
        Exit
    }

    [array]$WorkingFolders = @(Start-Searching -InputPath $script:InputPath -CatalogFolder $script:CatalogFolder -Extensions $script:Extensions)
    Invoke-Pause

    Start-Cleaning -ToClean $WorkingFolders -InputPath $script:InputPath
    Invoke-Pause

    Start-XMPcleanup -InputPath $script:InputPath -WorkingFiles $WorkingFolders
    Invoke-Pause

    Write-ColorOut "$(Get-CurrentDate)  -" -NoNewLine -ForegroundColor Cyan
    if($script:errorcounter -le 0){
        Write-ColorOut "-  Done without errors!" -ForegroundColor Green
        Start-Sound -Success 1
        Start-Sleep -Seconds 1
    }else{
        Write-ColorOut "-  Done, though $($script:errorcounter) error(s) were encountered." -ForegroundColor Magenta
        Start-Sound -Success 0
        Start-Sleep -Seconds 5
    }
    Invoke-Pause
}

Start-Everything
