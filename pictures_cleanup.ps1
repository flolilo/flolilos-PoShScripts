#requires -version 3

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

        .PARAMETER paraInput
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
            .\pictures_cleanup.ps1 -paraInput "D:\My pictures" -catalog_Folder "dontdeleteme" -extensions @("*.ext1","*.ext2") -debug 1
#>
param(
    [string]$paraInput="D:\Eigene_Bilder\_CANON",
    [string]$catalog_folder="_Picture_Catalogs",
    [array]$extensions=(
        "*.arw",
        "*.avi",
        "*.cr2",
        "*.dng",
        "*.ext",
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
    [int]$debug = 0
)

$confirm = $(if($debug -eq 1){1}else{0})

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

# DEFINITION: Making Write-Host much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-Host
        
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

# DEFINITION: For the auditory experience:
Function Start-Sound($success){
    <#
        .SYNOPSIS
            Gives auditive feedback for fails and successes
        
        .DESCRIPTION
            Uses SoundPlayer and Windows's own WAVs to play sounds.

        .NOTES
            Date: 2018-08-22

        .PARAMETER success
            If 1 it plays Windows's "tada"-sound, if 0 it plays Windows's "chimes"-sound.
        
        .EXAMPLE
            For success: Start-Sound(1)
    #>
    $sound = New-Object System.Media.SoundPlayer -ErrorAction SilentlyContinue
    if($success -eq 1){
        $sound.SoundLocation = "C:\Windows\Media\tada.wav"
    }else{
        $sound.SoundLocation = "C:\Windows\Media\chimes.wav"
    }
    $sound.Play()
}

if((Test-Path -LiteralPath $paraInput -PathType Container) -eq $false){
    Write-ColorOut "Folder non-existent!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

[int]$errorcounter = 0
[int]$changecounter = 100
$sw_A = [diagnostics.stopwatch]::StartNew()

while($changecounter -ne 0){
    $changecounter = 0
    [array]$folder = @()
    [int]$counter_A = 1
    $folder = @(Get-ChildItem -LiteralPath $paraInput -Directory | Where-Object {$_.BaseName -notmatch $catalog_folder} | ForEach-Object {
        if($sw_A.Elapsed.TotalMilliseconds -ge 500 -or $counter_A -eq 1){
            Write-Progress -Id 1 -Activity "Getting folders..." -Status "# $counter_A - $($_.BaseName)" -PercentComplete -1
            $sw_A.Reset()
            $sw_A.Start()
        }
        $counter_A++
        [int]$counter_B = 0
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            FileCount = @(Get-ChildItem -LiteralPath $_.FullName -File -Include $extensions).count

            [int]$counter_B = 0
            SubFolder = @(Get-ChildItem -LiteralPath $_.FullName -Directory -Recurse | ForEach-Object {
                if($sw_A.Elapsed.TotalMilliseconds -ge 500 -or $counter_A -eq 1){
                    Write-Progress -Id 2 -Activity "    Getting subfolders..." -Status "    # $counter_B - $($_.BaseName)" -PercentComplete -1
                    $sw_A.Reset()
                    $sw_A.Start()
                }
                $counter_B++
                [PSCustomObject]@{
                    FullName = $_.FullName
                    BaseName = $_.BaseName
                    FileCount = @(Get-ChildItem -LiteralPath $_.FullName -File -Include $extensions -Recurse).count
                }
            })
        }
    })
    Write-Progress -Id 1 -Activity "Getting folders..." -Status "Ready" -Completed
    Write-Progress -Id 2 -Activity "    Getting subfolders..." -Status "    Ready" -Completed

    $folder = $folder | Sort-Object -Property FullName,SubFolder.FullName
    $folder | Out-Null

    Write-ColorOut "Folder structure:" -ForegroundColor Cyan
    for($i=0; $i -lt $folder.Length; $i++){
        Write-ColorOut "$($folder[$i].BaseName) - $($folder[$i].filecount)"
        for($j=0; $j -lt $folder[$i].subfolder.Length; $j++){
            Write-ColorOut "|---- $($folder[$i].subfolder[$j].BaseName) - $($folder[$i].subfolder[$j].filecount)" -ForegroundColor DarkGray
        }
    }
    Start-Sleep -Seconds 5

    Write-ColorOut "Now looking for folders to delete..." -ForegroundColor Cyan
    for($i=0; $i -lt $folder.Length; $i++){
        if($folder[$i].subfolder.Length -ne 0){
            for($j=0; $j -lt $folder[$i].subfolder.Length; $j++){
                if($folder[$i].subfolder[$j].filecount -eq 0){
                    Write-ColorOut "$($folder[$i].subfolder[$j].FullName.Replace($paraInput,"."))`t`thas $($folder[$i].subfolder[$j].filecount) files." -ForegroundColor DarkGray
                    if($confirm -eq 1){
                        Write-ColorOut (Get-ChildItem -LiteralPath $folder[$i].subfolder[$j].FullName -File -Recurse | Select-Object -ExpandProperty Name)
                    }
                    if($confirm -eq 0 -or ($confirm -eq 1 -and (Read-Host "Is that okay? 1 for yes, 0 for no") -eq 1)){
                        try{
                            Remove-Item -LiteralPath $folder[$i].subfolder[$j].FullName -Recurse
                        }catch{
                            Write-ColorOut "Removing failed!" -ForegroundColor Magenta
                            $errorcounter++
                        }
                        $changecounter++
                    }
                }else{
                    Write-ColorOut "$($folder[$i].subfolder[$j].FullName.Replace($paraInput,"."))`t`thas $($folder[$i].subfolder[$j].filecount) files." -ForegroundColor DarkGreen
                }
            }
        }else{
            if($folder[$i].filecount -eq 0){
                Write-ColorOut "$($folder[$i].FullName.Replace($paraInput,"."))`t`thas $($folder[$i].subfolder[$j].filecount) files." -ForegroundColor DarkGray
                if($confirm -eq 1){
                    Write-ColorOut (Get-ChildItem -LiteralPath $folder[$i].FullName -File -Recurse | Select-Object -ExpandProperty Name)
                }
                if($confirm -eq 0 -or ($confirm -eq 1 -and (Read-Host "Is that okay? 1 for yes, 0 for no") -eq 1)){
                    try{
                        Remove-Item -LiteralPath $folder[$i].FullName -Recurse
                    }catch{
                        Write-ColorOut "Removing failed!" -ForegroundColor Magenta
                        $errorcounter++
                    }
                    $changecounter++
                }
            }else{
                Write-ColorOut "$($folder[$i].FullName.Replace($paraInput,"."))`t`thas $($folder[$i].subfolder[$j].filecount) files." -ForegroundColor DarkGreen
            }
        }
    }
}

if($errorcounter -eq 0){
    Write-ColorOut "Done without errors!" -ForegroundColor Green
    Start-Sound(1)
}else{
    Write-ColorOut "Done, though $errorcounter error(s) were encountered." -ForegroundColor Magenta
    Start-Sound(0)
}

Pause
