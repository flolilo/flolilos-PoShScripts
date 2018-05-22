#requires -version 3

param(
    [string]$InputPath =    "$((Get-Location).Path)",
    [int]$wantVerbose =     0,
    [int]$wantWhatif =      0
)

# DEFINITION: Get all error-outputs in English:
    [Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
    $OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding
    [Console]::InputEncoding = New-Object -TypeName System.Text.UTF8Encoding


# ==================================================================================================
# ==============================================================================
#    Defining generic functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Making Write-ColorOut much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-Host
        .DESCRIPTION
            Using the [Console]-commands to make everything faster.
        .NOTES
            Date: 2018-05-22
        
        .PARAMETER Object
            String to write out
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.

        .EXAMPLE
            Just use it like Write-Host.
    #>
    param(
        [string]$Object = "Write-ColorOut was called, but no string was transfered.",

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
            Date: 2018-03-12

        .PARAMETER Success
            1 plays Windows's "tada"-sound, 0 plays Windows's "chimes"-sound.
        
        .EXAMPLE
            For success: Start-Sound 1
        .EXAMPLE
            For fail: Start-Sound 0
    #>
    param(
        [int]$Success = $(return $false)
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

Function Start-All(){
    param([string]$InPath = $(throw 'InPath is required by Start-FileSearch'))

    if((Test-Path -LiteralPath $InPath -PathType Container) -eq $false){
        Write-ColorOut "Cannot find path!" -ForegroundColor Magenta -Indentation 2
        return $false
    }else{
        $AllFiles = @(Get-ChildItem -LiteralPath $InPath -File | ForEach-Object {
            [PSCustomObject]@{
                FullName = $_.FullName
                BaseName = $_.BaseName
                Extension = $_.Extension
            }
        })
    }
    $DeleteFiles = @($AllFiles | Sort-Object -Unique -Property BaseName)
    $DeleteFiles | Format-Table -AutoSize
}

Start-All -InPath $InputPath