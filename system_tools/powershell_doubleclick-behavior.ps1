#requires -version 2

<#
    .SYNOPSIS
        This script will allow you to change the standard doubleclick-behavior of .ps1-files.

    .DESCRIPTION
        This script will allow you to change the standard doubleclick-behavior of .ps1-files.

    .INPUTS
        None
    .OUTPUTS
        None

    .NOTES
        Version:        1.0
        Author:         flolilo
        Creation Date:  2017-09-09

    .PARAMETER userChoice
        Default value: -1 (prompt)
        Directly set the value to "open with PowerShell" (1) or "open with default" (0).
        Will only work when script is already run as administator.

    .EXAMPLE
        powershell_doubleclick-behavior.ps1
#>
param(
    [int]$userChoice = -1
)
#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding
# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

# Starting script as administrator:
if ((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) -eq $false){
    Write-Host "This script will ask for admin-rights. It changes the standard-behavior when doubleclicking a *.ps1-file." -ForegroundColor Cyan
    Write-Host "Dieses Skript wird um Administrator-Rechte fragen. Es aendert das Verhalten bei Doppelklicks auf *.ps1-Dateien." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Getting the desired behavior:
Write-Host "Type `"1`" (without quotes) for `"open with PowerShell`", type `"0`" for `"open with Notepad`" (standard). Confirm with Enter." -ForegroundColor Cyan
Write-Host "`"1`" (ohne Anfuehrungszeichen) eingeben fuer `"mit PowerShell oeffnen`", `"0`" fuer `"mit Editor oeffnen`" (Standard). Bestaetigen mit Enter." -ForegroundColor Yellow
while($userChoice -notin (0..1)){
    try{
        [int]$userChoice = Read-Host "Choice / Auswahl"
    }
    catch{
        continue
    }
}

# CREDIT: http://stackoverflow.com/a/35505293
New-PSDrive HKCR Registry HKEY_CLASSES_ROOT

# Open script directly:
if($userChoice -eq 1){
    try{
        Set-ItemProperty -Path HKCR:\Microsoft.PowerShellScript.1\Shell -Name '(Default)' -Value 0 -Verbose
        Write-Host "Setting registry succeeded!" -ForegroundColor Green
        Start-Sleep -Seconds 1
    }catch{
        Write-Host "Setting registry failed!" -ForegroundColor Red
        Start-Sleep -Seconds 5
    }
}

# Default (Notepad):
if($userChoice -eq 0){
    try{
        Set-ItemProperty -Path HKCR:\Microsoft.PowerShellScript.1\Shell -Name '(Default)' -Value 'Open' -Verbose
        Write-Host "Setting registry succeeded!" -ForegroundColor Green
        Start-Sleep -Seconds 1
    }catch{
        Write-Host "Setting registry failed!" -ForegroundColor Red
        Start-Sleep -Seconds 5
    }
}
