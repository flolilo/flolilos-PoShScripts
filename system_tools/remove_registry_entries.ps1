#requires -version 5

<#
    .SYNOPSIS
        This script will allow you to remove some unecessary context menu entries.
    .DESCRIPTION
        Please be careful with using this tool!
    .NOTES
        Version:        1.2
        Creation Date:  2018-04-09
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT"-tags to find them.
#>

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

[switch]$wantverbose = $true
[switch]$wantwhatif = $true

# Starting the script as admin, getting some user values:
if((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) -eq $false){
    Write-Host "This script will ask for admin-rights. It changes the standard-behavior when doubleclicking a *.ps1-file." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}else{
    [switch]$wantverbose = $(if((Read-Host "Want some verbose? (To see what's happening)`t") -eq 1){$true}else{$false})
    [switch]$wantwhatif = $(if((Read-Host "Activate dry-running? (Only show what would happen, not actually doing anything)`t") -eq 1){$true}else{$false})
    Write-Host "`r`nThis script will change values in your system's Registry, so perhaps it would be a good moment to export (save) your Registry NOW.`r`n" -ForegroundColor Magenta
    if((Read-Host "Backup registry now?") -eq 1){
        try{
            [string]$inter = Read-Host "Please specify path (and name) to save .reg-file at:`t"
            Start-process regedit -ArgumentList "/e $($inter).reg" -Wait -NoNewWindow
        }catch{
            Write-Host "Could not backup registry!" -ForegroundColor Magenta
            Pause
        }
    }
}

# DEFINITION: Create HKCR as drive for PS:
try{
    New-PSDrive -PSProvider Registry -Root HKEY_CLASSES_ROOT -Name HKCR -Verbose:$wantverbose -WhatIf:$false
}catch{
    Write-Host "Failed to create PSDrive." -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}

# DEFINITION: Remove Windows Media Player from context menu:
# CREDIT: https://superuser.com/a/235385/703240
if((Read-Host "Remove Windows Media Player from context menu?") -eq 1){
    Write-Host "Remove Windows Media Player from context menu..." -ForegroundColor Cyan
    [array]$regpath = @()
    $regpath += "HKCR:\SystemFileAssociations\Directory.Audio\shell\Enqueue"
    $regpath += "HKCR:\SystemFileAssociations\Directory.Audio\shell\Play"
    $regpath += "HKCR:\SystemFileAssociations\Directory.Audio\shellex\ContextMenuHandlers\WMPShopMusic"
    $regpath += "HKCR:\SystemFileAssociations\Directory.Image\shell\Enqueue"
    $regpath += "HKCR:\SystemFileAssociations\Directory.Image\shell\Play"
    $regpath += "HKCR:\SystemFileAssociations\Directory.Video\shell\Enqueue"
    $regpath += "HKCR:\SystemFileAssociations\Directory.Video\shell\Play"
    $regpath += "HKCR:\SystemFileAssociations\audio\shell\Enqueue"
    $regpath += "HKCR:\SystemFileAssociations\audio\shell\Play"
    $regpath += "HKCR:\SystemFileAssociations\video\shell\Enqueue"
    $regpath += "HKCR:\SystemFileAssociations\video\shell\Play"

    foreach($i in $regpath){
        if(Test-Path -Path $i){
            try{
                Remove-Item -Path $i -Recurse -Verbose:$wantverbose -WhatIf:$wantwhatif
                Write-Host "Deleted $i" -ForegroundColor DarkGreen
            }catch{
                Write-Host "Could not delete $i" -ForegroundColor Red
            }
        }else{
            Write-Host "Could not find $i" -ForegroundColor Magenta
        }
    }
}

# DEFINITION: Remove Visual Studio from context menu:
# CREDIT: https://superuser.com/a/1178368/703240
if((Read-Host "Remove Visual Studio from context menu?") -eq 1){
    Write-Host "Remove Visual Studio from context menu..." -ForegroundColor Cyan
    [string]$regpath = "HKCR:\Directory\Background\shell\AnyCode"
    [string]$regname = "HideBasedOnVelocityId"
    $regvalue = 0x006698a6
    
    if((Test-Path -Path $regpath\$regname -ErrorAction SilentlyContinue) -eq $true -and (Get-ItemPropertyValue -Path $regpath -Name $regname -ErrorAction SilentlyContinue) -eq $regvalue){
        Write-Host "$regpath\$regname already set to $regvalue" -ForegroundColor DarkGreen
    }else{
        try{
            New-ItemProperty -Path $regpath -Type DWord -Name $regname -Value $regvalue -Verbose:$wantverbose -WhatIf:$wantwhatif
            Write-Host "Created $regpath\$regname" -ForegroundColor DarkGreen
        }catch{
            Write-Host "Could not create $regpath\$regname" -ForegroundColor Red
        }
    }
}

# DEFINITION: Disable OneDrive-folder in Explorer:
if((Read-Host "Disable OneDrive-folder in Explorer?") -eq 1){
    Write-Host "Disable OneDrive-folder in Explorer..." -ForegroundColor Cyan
    [array]$regpath = @()
    [array]$regname = @()
    [array]$regvalue = @()
    $regpath += "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    $regname += "System.IsPinnedToNameSpaceTree"
    $regvalue += 0x00000000
    $regpath += "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    $regname += "System.IsPinnedToNameSpaceTree"
    $regvalue += 0x00000000

    for($i=0; $i -lt $regpath.Length; $i++){
        if((Get-ItemPropertyValue -Path $regpath[$i] -Name $regname[$i] -ErrorAction SilentlyContinue) -eq $regvalue[$i]){
            Write-Host "$($regpath[$i])\$($regname[$i]) already set to $($regvalue[$i])" -ForegroundColor DarkGreen
        }else{
            try{
                New-ItemProperty -Path $regpath[$i] -Type DWord -Name $regname[$i] -Value $regvalue[$i] -Verbose:$wantverbose -WhatIf:$wantwhatif
                Write-Host "Created $($regpath[$i])\$($regname[$i])" -ForegroundColor DarkGreen
            }catch{
                Write-Host "Could not create $($regpath[$i])\$($regname[$i])" -ForegroundColor Red
            }
        }
    }
}

# DEFINITION: Remove Adobe Bridge CS6 from context menu:
# CREDIT: https://blog.ryantadams.com/2010/11/07/remove-browse-in-adobe-bridge-from-context-menu/
if((Read-Host "Remove Adobe Bridge CS6 from context menu?") -eq 1){
    Write-Host "Remove Adobe Bridge CS6 from context menu..." -ForegroundColor Cyan
    [string]$regpath = "HKCR:\Directory\shell\Bridge"
    if(Test-Path -Path $regpath){
        try{
            Remove-Item -Path $regpath -Recurse -Verbose:$wantverbose -WhatIf:$wantwhatif
            Write-Host "Deleted $regpath" -ForegroundColor DarkGreen
        }catch{
            Write-Host "Could not delete $regpath" -ForegroundColor Red
        }
    }else{
        Write-Host "Could not find $regpath" -ForegroundColor Magenta
    }
}

# DEFINITION: Remove "open with GitKraken"
# CREDIT: https://stackoverflow.com/a/46667564/8013879
if((Read-Host "Remove GitKraken from context menu?") -eq 1){
    Write-Host "Remove GitKraken from context menu..." -ForegroundColor Cyan
    [string]$regpath = "HKCR:\Directory\Background\shell\GitKraken"
    if(Test-Path -Path $regpath){
        try{
            Remove-Item -Path $regpath -Recurse -Verbose:$wantverbose -WhatIf:$wantwhatif
            Write-Host "Deleted $regpath" -ForegroundColor DarkGreen
        }catch{
            Write-Host "Could not delete $regpath" -ForegroundColor Red
        }
    }else{
        Write-Host "Could not find $regpath" -ForegroundColor Magenta
    }
}

# DEFINITION: Add '0pen with' on top of context menu:
# CREDIT: https://superuser.com/questions/1281615
[int]$inter = Read-Host "Add/remove '0pen with' on top of context menu? 1 = `"add`", 2 `"remove`", 0 = `"I'm fine, thanks`"."
if($inter -eq 1){
    Write-Host "Add '0pen with' on top of context menu..." -ForegroundColor Cyan
    [string]$regpath = "HKCR:\*\shell\0pen With"
    if((Test-Path -LiteralPath $regpath) -eq $false){
        try{
            New-Item -Path $regpath -Verbose:$wantverbose -WhatIf:$wantwhatif
            Write-Host "Added key $regpath" -ForegroundColor DarkGreen
            New-Item -Path "$regpath\command" -Verbose:$wantverbose -WhatIf:$wantwhatif
            Write-Host "Added key $regpath\command" -ForegroundColor DarkGreen
        }catch{
            Write-Host "Could not create key $regpath or $regpath\command" -ForegroundColor Red
            $myerror=1
        }
    }
    if($myerror -ne 1){
        try{
            New-ItemProperty -LiteralPath $regpath -Name "Position" -Value "Top" -PropertyType String -Verbose:$wantverbose -WhatIf:$wantwhatif
            Write-Host "Added String `"Postition=Top`"" -ForegroundColor DarkGreen
            New-ItemProperty -LiteralPath "$regpath\command" -Name "(Default)" -Value "{09799AFB-AD67-11d1-ABCD-00C04FC30936}" -PropertyType String -Verbose:$wantverbose -WhatIf:$wantwhatif
            Write-Host "Added String `"(Default)={09799AFB-AD67-11d1-ABCD-00C04FC30936}`"" -ForegroundColor DarkGreen
        }catch{
            Write-Host "Could not create Strings in $regpath" -ForegroundColor Red
        }
    }
}elseif($inter -eq 2){
    [string]$regpath = "HKCR:\*\shell\0pen With"
    try{
        Remove-Item -LiteralPath $regpath -Recurse -Verbose:$wantverbose -WhatIf:$wantwhatif
        Write-Host "Deleted $regpath" -ForegroundColor DarkGreen
    }catch{
        Write-Host "Could not delete $regpath" -ForegroundColor Red
    }
}


Write-Host "Done!" -ForegroundColor Green
Remove-PSDrive -Name HKCR  -Verbose:$wantverbose -WhatIf:$false

Pause
