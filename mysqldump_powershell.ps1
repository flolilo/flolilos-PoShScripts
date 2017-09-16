#requires -version 3

<#
    .SYNOPSIS
        NOT YET WORKING! Replace the bash-script I never really understood with a PowerShell-one.
    .DESCRIPTION
        NOT YET WORKING!
        1)  See if path is bigger than threshold - if so, delete files that are older than the date threshold.
        2)  Do a MySQLdump
    .NOTES
        Version:    0.1
        Date:       2017-09-11
        Author:     flolilo
    .PARAMETER OutPath
        Path to save MySQLdump to.
    .PARAMETER DumpBaseName
        BaseName of the dump-file. Default: the current date in yyyy-MM-dd - scheme.
    .PARAMETER ThreshSize
        In MB. Threshold of size of folder before oldest files get deleted.
    .PARAMETER ThreshDay
        In days. Threshold of time: if actual size >= -ThreshSize, delete files older than -ThreshDay
#>
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path -Path $_ -PathType Container})]
    [string]$OutPath,

    [Parameter(Mandatory=$false)]
    [string]$DumpBaseName = "mysqldump_$(Get-Date -Format "yyyy-MM-dd").sql",

    [Parameter(Mandatory=$false)]
    [ValidateRange(1,102400)]
    [int]$ThreshSize = 128,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1,3653)]
    [int]$ThreshDay = 84,

    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$true)]
    [string]$UserPass
)
[int]$SizeFiles = 0
Write-Output "$(Get-Date -Format "yy-MM-dd HH:mm:ss") - Starting script."


Write-Output "$(Get-Date -Format "yy-MM-dd HH:mm:ss") - Checking folder size..."
[array]$existing_files = @(Get-ChildItem -Path $OutPath -Filter "*.gz" | ForEach-Object {
    $SizeFiles += $_.Length
    [PSCustomObject]@{
        FullName = $_.FullName
        Name = $_.Name
        LastWriteTime = $_.LastWriteTime
    }
})
if(($SizeFiles / 1MB) -gt $ThreshSize){
    Write-Output "$([math]::round($SizeFiles / 1MB)) MB > $Threshsize MB, so deleting files that are older than $ThreshDay days..."
    $existing_files = $existing_files | Where-Object {(New-TimeSpan -Start $_.LastWriteTime -End $(Get-Date)).TotalDays -gt $ThreshDay}
    $existing_files | Format-Table -AutoSize
    foreach($i in $existing_files.FullName){
        Remove-Item -Path $i -Verbose
    }
}else{
    Write-Output "$([math]::round($SizeFiles / 1MB)) MB <= $Threshsize MB, no files to delete..."
}


Write-Output "$(Get-Date -Format "yy-MM-dd HH:mm:ss") - Starting MySQL-dump..."
mysqldump --user=$UserName --password=$UserPass --events --all-databases | gzip -7 > $($OutPath)$($DumpBaseName).gz

Write-Output "$(Get-Date -Format "yy-MM-dd HH:mm:ss") - Script finished."
