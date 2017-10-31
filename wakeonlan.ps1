#requires -version 2

<#
    .NOTES
        CREDIT: wolcmd by https://www.depicus.com/wake-on-lan/wake-on-lan-cmd
#>

# DEFINITION: Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding

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

# DEFINITION: Get JSON values:
try{
    $JSON = Get-Content -Path "$($PSScriptRoot)\wakeonlan.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $JSON | Out-Null
    [array]$IPaddresses = $JSON.IPaddresses
    [array]$MACaddresses = $JSON.MACaddresses
    [string]$WOLcmdPath = $JSON.WOLcmdPath
}catch{
    Write-ColorOut "Failed to get $($PSScriptRoot)\wakeonlan.json - aborting!" -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}
if((Test-Path -Path $WOLcmdPath -PathType Leaf) -eq $false){
    Write-ColorOut "Cannot find $WOLcmdPath - aborting!" -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}


for($i=0; $i -lt $IPaddresses.Length; $i++){
    $MACaddresses[$i] = $MACaddresses[$i].Replace(":","")
    if(Test-Connection $IPaddresses[$i] -buffer 16 -Count 2 -Quiet){
        Write-ColorOut "Server $($i + 1)/$($IPaddresses.Length) already running!" -ForegroundColor Green
    }else{
        Write-ColorOut "Server $($i + 1)/$($IPaddresses.Length) not running - waking up..." -ForegroundColor Yellow
        Start-Process -FilePath $WOLcmdPath -ArgumentList "$($MACaddresses[$i]) $($IPaddresses[$i]) 255.255.255.0 7" -NoNewWindow -Wait
    }
    Start-Sleep -Milliseconds 500
}
