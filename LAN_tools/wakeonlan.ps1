#requires -version 2

<#
    .SYNOPSIS
        Ping and wake up server(s).
    .DESCRIPTION
        CREDIT: wolcmd by https://www.depicus.com/wake-on-lan/wake-on-lan-cmd
    .NOTES
        Version:    1.3
        Date:       2018-02-22
        Author:     flolilo
#>
param(
    [string]$InputFile =    "$($PSScriptRoot)\wakeonlan.json",
    [string]$IPaddress =    "",
    [string]$MACaddress =   "",
    [string]$WOLcmdPath =   "C:\FFMPEG\binaries\WolCmd.exe"
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

# DEFINITION: Getting date and time in pre-formatted string:
Function Get-CurrentDate(){
    return $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

# ==================================================================================================
# ==============================================================================
#    Defining specific functions:
# ==============================================================================
# ==================================================================================================

# DEFINITION: Get JSON values:
Function Get-Values(){
    Write-ColorOut "$(Get-CurrentDate)  --  Finding values..." -ForegroundColor Cyan
    # DEFINITION: If you have more than 11 servers to check (I somehow find that unlikely), then turn up (0..10) to (0..999) or whatever you like!
    [array]$script:WOL = @((0..10) | ForEach-Object {
        [PSCustomObject]@{
            Name = "ZYX"
            MACaddress = "ZYX"
            IPaddress = "ZYX"
        }
    })
    if($script:IPaddress.Length -eq 0 -or $script:MACaddress.Length -eq 0){
        try{
            Test-Path -Path $script:InputFile -PathType Leaf -ErrorAction Stop | Out-Null
            $inter = Get-Content -Path $script:InputFile -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            for($i=0; $i -lt $inter.Length; $i++){
                $script:WOL[$i].Name = $inter[$i].Name
                $script:WOL[$i].MACaddress = $inter[$i].MACaddress.Replace(":","")
                $script:WOL[$i].IPaddress = $inter[$i].IPaddress
            }
        }catch{
            Write-ColorOut "Failed to get $script:InputFile - aborting!" -ForegroundColor Red
            Start-Sleep -Seconds 5
            Exit
        }
    }else{
        $script:WOL[0].Name = "UserServer"
        $script:WOL[0].MACaddress = $script:MACaddress.Replace(":","")
        $script:WOL[0].IPaddress = $script:IPaddress
    }

    $script:WOL | Out-Null
    $script:WOL = @($script:WOL | Where-Object {$_.Name -ne "ZYX" -and $_.IPaddress -ne "ZYX" -and $_.MACaddress -ne "ZYX"})
    $script:WOL | Out-Null
}

# DEFINITION: Ping and WOL:
Function Start-WOL(){
    Write-ColorOut "$(Get-CurrentDate)  --  Pinging/waking server(s)..." -ForegroundColor Cyan

    for($i=0; $i -lt $script:WOL.Count; $i++){
        Write-Progress -Activity "Pinging server(s)..." -Status "# $($i + 1)/$($script:WOL.Count) - `"$($script:WOL[$i].Name)`"" -PercentComplete $((($i + 1) * 100) / $script:WOL.Count)
        if((Test-Connection -ComputerName $script:WOL[$i].IPaddress -Buffer 16 -TimeToLive 2 -Delay 1 -Count 2 -Quiet) -eq $true){
            Write-ColorOut "Server $($i + 1)/$($script:WOL.Count) - `"$($script:WOL[$i].Name)`" is already running!" -ForegroundColor Green -Indentation 4
        }else{
            Write-ColorOut "Server $($i + 1)/$($script:WOL.Count) - `"$($script:WOL[$i].Name)`" is not running - waking up..." -ForegroundColor Yellow -Indentation 4
            Start-Process -FilePath $script:WOLcmdPath -ArgumentList "$($script:WOL[$i].MACaddress) $($script:WOL[$i].IPaddress) 255.255.255.0 7" -NoNewWindow -Wait
        }
    }
    Write-Progress -Activity "Pinging/waking server..." -Status "Done!" -Completed
}


Function Start-Everything(){
    Write-ColorOut "                                  A" -BackgroundColor DarkGray -ForegroundColor DarkGray
    Write-ColorOut "        flolilo's WOLscript        " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "         v1.2 - 2018-01-27         " -ForegroundColor DarkCyan -BackgroundColor Gray
    Write-ColorOut "(PID = $("{0:D8}" -f $pid))                   `r`n`r`n`r`n" -ForegroundColor Gray -BackgroundColor DarkGray

    if((Test-Path -Path $script:WOLcmdPath -PathType Leaf) -eq $false){
        Write-ColorOut "Cannot find $($script:WOLcmdPath) - aborting!" -ForegroundColor Red
        Start-Sleep -Seconds 5
        Exit
    }

    Get-Values
    Start-WOL
 
    Write-ColorOut "$(Get-CurrentDate)  --  Done!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

Start-Everything
