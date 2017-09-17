#requires -version 2

<#
    .SYNOPSIS
        This script will document the computer's CPU- and RAM-stats.

    .DESCRIPTION
        Script will watch for instances of defined -process and will acquire the average usage (in %) and the used RAM every second until that process is finished. It can then -write the stats to an -outfile.

    .INPUTS
        None
    .OUTPUTS
        CSV-file with stats. If -outfile isn't defined, then it will be found in under <script path>\stats.csv

    .NOTES
        Version:        0.1
        Author:         flolilo
        Creation Date:  2017-08-18 (GitHub release)

    .PARAMETER write
        1 enables writing out -outfile, 0 disables it.
    .PARAMETER process
        Process that will limit the watching time. E.g. if "ffmpeg" is specified, the script will work until all instances of ffmpeg are finished.
    .PARAMETER mode
        NOT YET IMPLEMENTED. I have to confess that at the moment, I don't know what this should have done.
    .PARAMETER outfile
        Path to outfile - must end with ".csv".

    .EXAMPLE
        cpuwatch.ps1 -write 1 -process "ffmpeg"
#>

param(
    [int]$write=1,
    [string]$process="powershell",
    [string]$mode,
    [string]$outfile="$($PSScriptRoot)\stats.csv"
)
[int]$done = 0
[array]$date = @()
[array]$cpu = @()
[array]$ram = @()

Function Get-ComputerStats(){
    $script:cpu += Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | ForEach-Object {
        # Write-Host "$($_.Average)"
        $_.Average
    }
    $script:ram += Get-WmiObject win32_operatingsystem | ForEach-Object {
        "{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize)
    }
}

# DEFINITION: for timing:
while($done -le 15){
    $date += Get-Date -Format "dd.MM.yy HH:mm:ss"
    Get-ComputerStats
    $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name $process).count
    if($process -eq "powershell"){
        $activeProcessCounter--
    }
    if($activeProcessCounter -eq 0){
        $done++
    }else{
        $done = 0
    }
    Start-Sleep -Seconds 1
}


if($write -eq 1){
    $resultsarray = @()
    for($i = 0; $i -lt $date.Length; $i++){
        $verifiedObject = new-object PSObject
        $verifiedObject | add-member -membertype NoteProperty -name "Date" -Value $date[$i]
        $verifiedObject | add-member -membertype NoteProperty -name "CPU" -Value $cpu[$i]
        $verifiedObject | add-member -membertype NoteProperty -name "RAM" -Value $ram[$i]
        $resultsarray += $verifiedObject
    }
    $resultsarray| Export-csv $outfile -notypeinformation -Encoding UTF8
}
Write-Host "Done!" -ForegroundColor Green
Pause
