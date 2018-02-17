#requires -version 3

# TODO: TODO: Proper documentation, Remove-ItemSafely TODO: TODO:
<#
    .SYNOPSIS
        Deletes subfolders that don't contain specified extensions

    .DESCRIPTION


    .NOTES
        Version:        1.2
        Author:         flolilo
        Creation Date:  2017-09-09
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT:"-tags to find them.

        .PARAMETER $script:InputPath
            Path to check
        .PARAMETER catalog_folder
            Folder that should be excluded
        .PARAMETER extension
            Extensions that are searched for: if these exist in a folder, it will not be deleted.
        .PARAMETER debug
            Adds confirmation-dialogs for removal of folders.

        .INPUTS
            None.
        .OUTPUTS
            None.

        .EXAMPLE
            .\pictures_cleanup.ps1 -$script:InputPath "D:\My pictures" -catalog_Folder "dontdeleteme" -extensions @("*.ext1","*.ext2") -debug 1
#>
param(
    [string]$InputPath = "D:\Eigene_Bilder\_CANON",
    [string]$catalog_folder = "_Picture_Catalogs",
    [array]$extensions = @(
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
    [int]$debug = 1
)

[int]$confirm = $(if($debug -eq 1){1}else{0})

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

[int]$errorcounter = 0

Function Start-Searching(){
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputPath,
        [Parameter(Mandatory=$true)]
        [string]$catalog_folder,
        [Parameter(Mandatory=$true)]
        [array]$extensions
    )

    $sw_A = [diagnostics.stopwatch]::StartNew()
    [int]$sw_counter = 0
    $folder = @(Get-ChildItem -LiteralPath $InputPath -Directory -Recurse | Where-Object {$_.FullName -notmatch $catalog_folder} | ForEach-Object {
        if($sw_A.Elapsed.TotalMilliseconds -ge 500 -or $sw_counter -eq 0){
            Write-Progress -Activity "Getting folders..." -Status "# $sw_counter - $($_.FullName)" -PercentComplete -1
            $sw_A.Reset()
            $sw_A.Start()
        }
        $sw_counter++
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            FileCount = 0
            # SubfolderCount = (Get-ChildItem -Path $_.FullName -Directory).count
        }
    })
    Write-Progress -Activity "Getting folders..." -Status "Done" -Completed

    [int]$sw_counter = 0
    for($i=0; $i -lt $folder.Length; $i++){
        if($sw_A.Elapsed.TotalMilliseconds -ge 500 -or $sw_counter -eq 0){
            Write-Progress -Activity "Getting files..." -Status "# $sw_counter - $($folder[$i].FullName)" -PercentComplete ($i * 100 / $folder.Length)
            $sw_A.Reset()
            $sw_A.Start()
        }
        $sw_counter++
        foreach($j in $extensions){
            [int]$folder[$i].FileCount += (Get-ChildItem -LiteralPath $folder[$i].FullName -Filter $j -Recurse).Count
        }
    }
    Write-Progress -Activity "Getting files..." -Status "Done" -Completed


    $folder = $folder | Sort-Object -Property FullName -Descending
    $folder | Out-Null

    return $folder
}

Function Start-Cleaning(){
    param(
        [Parameter(Mandatory=$true)]
        [array]$ToClean,
        [Parameter(Mandatory=$true)]
        [string]$InputPath
    )

    Write-ColorOut "Now looking for folders to delete..." -ForegroundColor Cyan
    for($i=0; $i -lt $ToClean.Length; $i++){
        if($ToClean[$i].filecount -eq 0){
            Write-ColorOut "$($ToClean[$i].FullName.Replace($InputPath,"."))`t`thas $($ToClean[$i].filecount) files." -ForegroundColor DarkGray
            if($confirm -eq 1){
                $inter = Get-ChildItem -LiteralPath $ToClean[$i].FullName -File -Recurse | Sort-Object -Property Extension,BaseName
                $inter | Format-Table -AutoSize -Property BaseName,Extension,Length
            }
            if($confirm -eq 0 -or ($confirm -eq 1 -and (Read-Host "Is that okay? 1 for yes, 0 for no") -eq 1)){
                try{
                    Remove-Item -LiteralPath $ToClean[$i].FullName -Recurse -Verbose
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

Function Start-DocSearch(){
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputPath,
        [Parameter(Mandatory=$true)]
        [array]$extensions
    )

    $sw_A = [diagnostics.stopwatch]::StartNew()

    [int]$sw_counter = 0
    [array]$files = Get-ChildItem -Path $ToClean[$i].FullName -Filter *.xmp -Recurse | ForEach-Object -Process {
        if($sw_A.Elapsed.TotalMilliseconds -ge 500 -or $sw_counter -eq 0){
            Write-Progress -Activity "Getting folders..." -Status "# $i - $($ToClean[$i].FullName)" -PercentComplete -1
            $sw_A.Reset()
            $sw_A.Start()
        }
        $sw_counter++

        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
        }
    } -End {Write-Progress -Activity "Checking XMPs..." -Status "Done" -Completed}

    for($i=0; $i -lt $files.Length; $i++){
        if($sw_A.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
            Write-Progress -Activity "Checking XMPs..." -Status "# $i - $($files[$i].FullName)" -PercentComplete -1
            $sw_A.Reset()
            $sw_A.Start()
        }
        [int]$counter = 0
        for($j=0; $j -lt $extensions.Length; $j++){
            [int]$counter += (Get-ChildItem -Path $ToClean[$i].FullName -Filter $extensions[$j]).count
        }
        if($counter -lt 1){
            Write-ColorOut "Only XMP!" -ForegroundColor Red
        }else{
            Write-ColorOut "XMP with file." -ForegroundColor Green
        }
    }
    Write-Progress -Activity "Checking XMPs..." -Status "Done" -Completed
}

Function Start-Everything(){
    [array]$folder = Start-Searching -InputPath $script:InputPath -catalog_folder $script:catalog_folder -extensions $script:extensions
    Start-Cleaning -ToClean $folder -InputPath $script:InputPath
    Start-DocSearch -InputPath $script:InputPath -extensions $script:extensions
    if($script:errorcounter -le 0){
        Write-ColorOut "Done without errors!" -ForegroundColor Green
        Start-Sound -Success 1
    }else{
        Write-ColorOut "Done, though $($script:errorcounter) error(s) were encountered." -ForegroundColor Magenta
        Start-Sound -Success 0
    }
}

if((Test-Path -LiteralPath $InputPath -PathType Container) -eq $false){
    Write-ColorOut "Folder non-existent!" -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}else{
    Start-Everything
    Pause
}
