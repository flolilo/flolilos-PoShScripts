#requires -version 3

<#
    .SYNOPSIS
        Lists file-types in folder(s).

    .DESCRIPTION
        

    .NOTES
        Version:        1.1
        Author:         flolilo
        Creation Date:  2017-09-08
        Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
        applicable law. Most of the script was written by myself (or heavily modified by me when searching for solutions
        on the WWW). However, some parts are copies or modifications of very genuine code - see
        the "CREDIT:"-tags to find them.

    .PARAMETER userIn
        paths to search through

    .PARAMETER ignore_filetypes
        filetypes to ignore

    .INPUTS
        none
    .OUTPUTS
        none
    
    .EXAMPLE
        find_extensions.ps1 -userIn "D:\Mypath","C:\Mypath" -ignore_filetype "*.avi","*.mp4"
#>
param(
    [array]$userIn = @(),
    [array]$ignore_filetypes = @("*.avi","*.mkv","*.mp4","*.mpg","*.pdf","*.jpg","*.png","*.txt","*.nfo","*.xml")
)

for($i=0; $i -lt $userIn.Length; $i++){
    Set-Location $($userIn[$i])
    Write-Host "Looking for files in $($userIn[$i])..." -ForegroundColor Yellow
    Get-Childitem -LiteralPath "$($userIn[$i])" -Recurse -Exclude $ignore_filetypes -File | Group-Object Extension -NoElement | Sort-Object count -desc
}

Pause
