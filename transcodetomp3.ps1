#requires -version 3

<#
    .SYNOPSIS
        Search and transcode all files that are not MP3s to get MP3s.

    .NOTES
        Version:    1.0
        Author:     flolilo
        Date:       2017-09-13

    .PARAMETER InPath
        Path to get (audio-) files from.

    .PARAMETER Encoder
        Path to FFmpeg.exe
#>
param(
    [Parameter(Mandatory=$true)] 
    [ValidateScript({Test-Path $_ -PathType 'Container'})]
    [string]$InPath,
    
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]$Encoder
)

$sw = [diagnostics.stopwatch]::StartNew()
$i=0
$InFiles = @(Get-ChildItem -Path $InPath -Exclude *.mp3 -File -Recurse | ForEach-Object -Process {
    if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
        Write-Progress -Activity "Searching files..." -Status $i -PercentComplete -1
        $sw.reset()
        $sw.start()
    }
    $i++
    [PSCustomObject]@{
        FullName = $_.FullName
        NewName = $_.FullName.Replace("$($_.Extension)",".mp3")
    }
} -End {Write-Progress -Activity "Searching files..." -Status "Done" -Completed})
Write-Host "$($InFiles.Length) files found." -ForegroundColor Gray
for($i=5; $i -gt 0; $i--){
    Write-Progress -Activity "Sleeping..." -SecondsRemaining $i
    Start-Sleep -Seconds 1
}

$counter = 0
for($i=0; $i -lt $InFiles.Length; $i++){
    if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
        Write-Progress -Activity "Transcoding..." -Status "$i / $($InFiles.Length)" -PercentComplete $(($i / $InFiles.Length) * 100)
        $sw.reset()
        $sw.start()
    }
    while($counter -gt 7){
        Start-sleep -Milliseconds 25
        $counter = @(Get-Process -Name "ffmpeg" -ErrorAction SilentlyContinue).count
    }
    Start-Process -FilePath $Encoder -ArgumentList " -loglevel fatal -hide_banner -i `"$($InFiles[$i].FullName)`" -vn -c:a libmp3lame -q:a 2 -compression_level 0 -id3v2_version 3 -n `"$($InFiles[$i].NewName)`"" -NoNewWindow
    $counter++
}
Write-Progress -Activity "Transcoding..." -Status "Complete" -Completed

$counter = @(Get-Process -Name "ffmpeg" -ErrorAction SilentlyContinue).count
while($counter -gt 0){
    Start-sleep -Milliseconds 25
    $counter = @(Get-Process -Name "ffmpeg" -ErrorAction SilentlyContinue).count
}

for($i=5; $i -gt 0; $i--){
    Write-Progress -Activity "Sleeping..." -SecondsRemaining $i
    Start-Sleep -Seconds 1
}
Write-Progress -Activity "Sleeping..." -Completed

for($i=0; $i -lt $InFiles.Length; $i++){
    if($sw.Elapsed.TotalMilliseconds -ge 500 -or $i -eq 0){
        Write-Progress -Activity "Deleting..." -Status "$i / $($InFiles.Length)" -PercentComplete $(($i / $InFiles.Length) * 100)
        $sw.reset()
        $sw.start()
    }
    if(Test-Path -Path $InFiles[$i].NewName -PathType Leaf){
        Remove-Item $InFiles[$i].FullName -Verbose
    }else {
        # New-Item -Path "$($InFiles[$i].NewName)_broken"
        Write-Host "$($InFiles[$i].NewName) not found!" -ForegroundColor Red
    }
}
Write-Progress -Activity "Deleting..." -Status "Complete" -Completed


Pause
