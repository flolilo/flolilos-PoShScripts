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
        Version:        0.1
        Author:         flolilo
        Creation Date:  2017-08-18 (GitHub release)

    .EXAMPLE
        powershell_doubleclick-behavior.ps1
#>

#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding
# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

Write-Host "This script will ask for admin-rights. It changes the standard-behavior when doubleclicking a *.ps1-file." -ForegroundColor Cyan
Write-Host "Dieses Skript wird um Administrator-Rechte fragen. Es ändert das Verhalten bei Doppelklicks auf *.ps1-Dateien." -ForegroundColor Yellow

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
}

Write-Host "Type `"1`" (without quotes) for `"open with PowerShell`", type `"0`" for `"open with Notepad`" (standard). Confirm with Enter." -ForegroundColor Cyan
Write-Host "`"1`" (ohne Anführungszeichen) eingeben für `"mit PowerShell öffnen`", `"0`" für `"mit Editor öffnen`" (Standard). Bestätigen mit Enter." -ForegroundColor Yellow
while($true){
    try{
        [int]$userChoice = Read-Host "Choice / Auswahl"
        break
    }
    catch{
        continue
    }
}

# CREDIT: http://stackoverflow.com/a/35505293
New-PSDrive HKCR Registry HKEY_CLASSES_ROOT

if($userChoice -eq 1){
    # Open:
    Set-ItemProperty HKCR:\Microsoft.PowerShellScript.1\Shell '(Default)' 0
}
if($userChoice -eq 0){
    # Default (Notepad):
    Set-ItemProperty HKCR:\Microsoft.PowerShellScript.1\Shell '(Default)' 'Open'
}
