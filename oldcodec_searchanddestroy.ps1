#requires -version 3

<#
    .SYNOPSIS
        flolilo's Codec-Finder-Script v1.0
#>
param(
    [string]$decoder = "C:\FFMPEG\binaries\ffprobe.exe",
    [int]$runprobe = 1,
    [int]$deletion = 0,
    [int]$userinput = 0,
    [int]$debug = 0,
    [int]$writeout = 0
)

if($userinput -eq 1){
    [array]$userIn = @(Read-Host "Folder to be scanned")
    $deletion = Read-Host "Delete XML-files afterward? `"1`" for `"yes`", `"0`" for `"no`""
    $debug = Read-Host "Debug-Files?"
}Else{
    [array]$userIn = "Z:\Videos1"
    $userIn += "Z:\Videos2"
}

Clear-Host
Write-Host "Debug-Var: $debug" -ForegroundColor Cyan
Write-Host "WriteOut-Var: $writeout" -ForegroundColor Cyan
Write-Host "Run FFprobe: $runprobe" -ForegroundColor Cyan
Write-Host "Delete XML afterwards: $deletion" -ForegroundColor Cyan
Write-Host " "
Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "" -Encoding utf8
if($debug -eq 1){
    Out-File -FilePath R:\streamorder_files.txt -InputObject "" -Encoding utf8
    Out-File -FilePath R:\vidcod_files.txt -InputObject "" -Encoding utf8
    Out-File -FilePath R:\audcod_files.txt -InputObject "" -Encoding utf8
}

# Scanning for files:
for($j=0; $j -lt $userIn.Length; $j++){
    Set-Location $($userIn[$j])
    Write-Host "Looking for files in $($userIn[$j])" -ForegroundColor Yellow
    $dateien += Get-ChildItem -Path $($userIn[$j]) -Recurse -File -Include *.avi, *.mkv, *.mp4, *.mpg
}

$dateinamen = @($dateien.Name)
$dateipfade = @($dateien.Directory)
$dateipurname = @($dateien.BaseName)

# Running FFprobe (if enabled):
if($runprobe -eq 1){
    Write-Host "Start FFprobe" -ForegroundColor Yellow
    for($i=0; $i -lt $dateinamen.Length; $i++){
        while($prozesse -gt 12){
            $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffprobe).count
            Start-Sleep -Milliseconds 50
        }
        Write-Host "$($dateipfade[$i])\$($dateinamen[$i]) " -ForegroundColor Cyan
        Start-Process "cmd.exe" -ArgumentList "/c ffprobe -hide_banner -i `"$($dateipfade[$i])\$($dateinamen[$i])`" -print_format xml -show_streams -v quiet > `"$($dateipfade[$i])\$($dateipurname[$i]).xml`"" -NoNewWindow
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffprobe).count
    }
    Write-Host "Done with FFprobe-loop..." -ForegroundColor Yellow
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffprobe).count
        Start-Sleep -Milliseconds 100
    }
}

# Gathering XML-file-information:
Write-Host "Gathering XML-file-information" -ForegroundColor Yellow
for($i=0; $i -lt $dateinamen.Length; $i++){
    $xml = [xml](Get-Content "$($dateipfade[$i])\$($dateipurname[$i]).xml")
    [array]$bla_vid = $xml.ffprobe.streams.stream | Where-Object {$_.index -eq 0 -and $_.codec_type -eq "video"} | Select-Object -ExpandProperty codec_name
    [array]$bla_aud = $xml.ffprobe.streams.stream | Where-Object {$_.index -eq 0 -and $_.codec_type -eq "audio"} | Select-Object -ExpandProperty codec_name
    Try{
        [array]$bla_cha = ($xml.ffprobe.streams.stream | Where-Object {$_.index -eq 0 -and $_.codec_type -eq "audio"} | Select-Object -ExpandProperty channel_layout -ErrorAction Stop) -replace '\(side\)',''
    }
    Catch{
        [array]$bla_cha = ($xml.ffprobe.streams.stream | Where-Object {$_.index -eq 0 -and $_.codec_type -eq "audio"} | Select-Object -ExpandProperty channels) -replace '1','mono' -replace '2','stereo'
    }
    [array]$bla_sub = @($xml.ffprobe.streams.stream | Where-Object {$_.index -eq 0 -and $_.codec_type -eq "subtitle"} | Select-Object -ExpandProperty index)
    [array]$bla_rei = ($xml.ffprobe.streams.stream | Where-Object {$_.index -eq 0} | Select-Object -ExpandProperty codec_type) -replace 'video','v' -replace 'audio','a' -replace 'subtitle','s' -replace 'file','f' -replace 'attachment','f'
    for($k=1; $k -lt 12; $k++){
        $bla_vid += $xml.ffprobe.streams.stream | Where-Object {$_.index -eq $k -and $_.codec_type -eq "video"} | Select-Object -ExpandProperty codec_name
        $bla_aud += $xml.ffprobe.streams.stream | Where-Object {$_.index -eq $k -and $_.codec_type -eq "audio"} | Select-Object -ExpandProperty codec_name
        Try{
            $bla_cha += ($xml.ffprobe.streams.stream | Where-Object {$_.index -eq $k -and $_.codec_type -eq "audio"} | Select-Object -ExpandProperty channel_layout -ErrorAction Stop) -replace '\(side\)',''
        }
        Catch{
            $bla_cha += ($xml.ffprobe.streams.stream | Where-Object {$_.index -eq $k -and $_.codec_type -eq "audio"} | Select-Object -ExpandProperty channels) -replace '1','mono' -replace '2','stereo'
        }
        $bla_sub += $xml.ffprobe.streams.stream | Where-Object {$_.index -eq $k -and $_.codec_type -eq "subtitle"} | Select-Object -ExpandProperty index
        $bla_rei += ($xml.ffprobe.streams.stream | Where-Object {$_.index -eq $k} | Select-Object -ExpandProperty codec_type) -replace 'video','v' -replace 'audio','a' -replace 'subtitle','s' -replace 'file','f' -replace 'attachment','f'
    }
    
    if($writeout -eq 1){
        Write-Host "$bla_rei -- V: $bla_vid - A: $bla_aud $bla_cha - S: $bla_sub -- " -ForegroundColor Cyan -NoNewline
        Write-Host "$($dateipfade[$i])\$($dateinamen[$i])"
    }
    # if($bla_aud -like "DTS*" -or $bla_vid -like "mpeg1*" -or $bla_vid -like "mpeg2*" -or $bla_aud -like "mp2*" -or $bla_aud -like "truehd*"  -or $bla_aud -like "wmav2*" -or $($dateinamen[$i]) -like "*_OPUS*"){
    if($bla_aud -like "DTS*" -or $bla_vid -like "mpeg1*" -or $bla_vid -like "mpeg2*" -or $bla_aud -like "mp2*" -or $bla_aud -like "truehd*"  -or $bla_aud -like "wmav2*"){
        if($writeout -eq 1){
            Write-Host "$($dateipfade[$i])\$($dateinamen[$i])" -ForegroundColor Red
            Remove-Item -Path "$($dateipfade[$i])\$($dateinamen[$i])" -Confirm
        }
        [array]$trans_vid += "$($bla_vid[0])" + "§$($bla_vid[1])" + "§$($bla_vid[2])"
        [array]$trans_aud += "$($bla_aud[0])" + "§$($bla_aud[1])" + "§$($bla_aud[2])" + "§$($bla_aud[3])" + "§$($bla_aud[4])" + "§$($bla_aud[5])" + "§$($bla_aud[6])" + "§$($bla_aud[7])" + "§$($bla_aud[8])" + "§$($bla_aud[9])" + "§$($bla_aud[10])" + "§$($bla_aud[11])"
        [array]$trans_cha += "$($bla_cha[0])" + "§$($bla_cha[1])" + "§$($bla_cha[2])" + "§$($bla_cha[3])" + "§$($bla_cha[4])" + "§$($bla_cha[5])" + "§$($bla_cha[6])" + "§$($bla_cha[7])" + "§$($bla_cha[8])" + "§$($bla_cha[9])" + "§$($bla_cha[10])" + "§$($bla_cha[11])"
        if($bla_sub -gt 0){}
        [array]$trans_sub += "$($bla_sub[0])" + "§$($bla_sub[1])" + "§$($bla_sub[2])" + "§$($bla_sub[3])" + "§$($bla_sub[4])" + "§$($bla_sub[5])" + "§$($bla_sub[6])" + "§$($bla_sub[7])" + "§$($bla_sub[8])" + "§$($bla_sub[9])" + "§$($bla_sub[10])" + "§$($bla_sub[11])"
        [array]$trans_rei += "$($bla_rei[0])" + "§$($bla_rei[1])" + "§$($bla_rei[2])" + "§$($bla_rei[3])" + "§$($bla_rei[4])" + "§$($bla_rei[5])" + "§$($bla_rei[6])" + "§$($bla_rei[7])" + "§$($bla_rei[8])" + "§$($bla_rei[9])" + "§$($bla_rei[10])" + "§$($bla_rei[11])"
        [array]$trans_file += "$($dateipfade[$i])\$($dateinamen[$i])"
    }Else{
        if($writeout -eq 1){
            Write-Host "Everything is alright here." -ForegroundColor Green
        }
    }
    if($writeout -eq 1){
        Write-Host " "
    }
    if($debug -eq 1){
        $debug_rei = $bla_rei
        $debug_vid = $bla_vid -replace 'h264','§' -replace 'hevc','§' -replace 'mpeg4','§'
        $debug_aud = $bla_aud -replace 'opus','§' -replace 'ac3','§' -replace 'mp3','§' -replace 'dts','§' -replace 'aac','§' -replace 'vorbis','§'
        Out-File -FilePath R:\streamorder_files.txt -InputObject "$bla_rei -- $($dateipfade[$i])\$($dateinamen[$i])" -Encoding utf8 -Append
        Out-File -FilePath R:\vidcod_files.txt -InputObject "$debug_vid -- $($dateipfade[$i])\$($dateinamen[$i])" -Encoding utf8 -Append
        Out-File -FilePath R:\audcod_files.txt -InputObject "$debug_aud -- $($dateipfade[$i])\$($dateinamen[$i])" -Encoding utf8 -Append
    }
}

if($deletion -eq 1){
    Start-Sleep -Seconds 1
    Write-Host "Deleting XML-files..." -ForegroundColor Yellow
    for($j=0; $j -lt $userIn.Length; $j++){
        Set-Location $($userIn[$j])
        Get-ChildItem -Path $($userIn[$j]) -Recurse  -Include *.xml | ForEach-Object {Remove-Item -Path $_}
    }
}

Write-Host "`r`nDateien:" -ForegroundColor Green

# Read out gathered data:
$separator = "§"
$option = [System.StringSplitOptions]::RemoveEmptyEntries
for($i=0; $i -lt $trans_file.Length; $i++){
    $trans_vid_sp = @($($trans_vid[$i]).split($separator,$option))
    $trans_aud_sp = @($($trans_aud[$i]).split($separator,$option))
    $trans_cha_sp = @($($trans_cha[$i]).split($separator,$option))
    $trans_sub_sp = @($($trans_sub[$i]).split($separator,$option))
    $trans_rei_sp = @($($trans_rei[$i]).split($separator,$option))
    Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "$($trans_file[$i]) -- " -Encoding utf8 -Append -NoNewline
    Write-Host "$($trans_file[$i]) -- "
    for($k=0; $k -lt $trans_rei_sp.Length; $k++){
        Write-Host "$($trans_rei_sp[$k]) " -ForegroundColor Magenta -NoNewline
        Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "$($trans_rei_sp[$k]) " -Encoding utf8 -Append -NoNewline
    }
    Write-Host "-- " -NoNewline
    Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "-- " -Encoding utf8 -Append -NoNewline
    for($k=0; $k -lt $trans_vid_sp.Length; $k++){
        Write-Host "c:v:$($k) $($trans_vid_sp[$k]) " -NoNewline -ForegroundColor Cyan
        Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "c:v:$($k) $($trans_vid_sp[$k]) " -Encoding utf8 -Append -NoNewline
    }
    Write-Host "- " -NoNewline
    Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "- " -Encoding utf8 -Append -NoNewline
    for($k=0; $k -lt $trans_aud_sp.Length; $k++){
        Write-Host "c:a:$($k) $($trans_aud_sp[$k]) $($trans_cha_sp[$k]) " -NoNewline -ForegroundColor Yellow
        Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "c:a:$($k) $($trans_aud_sp[$k]) $($trans_cha_sp[$k]) " -Encoding utf8 -Append -NoNewline
    }
    Write-Host "- " -NoNewline
    Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "- " -Encoding utf8 -Append -NoNewline
    for($k=0; $k -lt $trans_sub_sp.Length; $k++){
        Write-Host "c:s:$($k) $($trans_sub_sp[$k]) " -NoNewline -ForegroundColor Green
        Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject "c:s:$($k) $($trans_sub_sp[$k]) " -Encoding utf8 -Append -NoNewline
    }
    Out-File -FilePath $PSScriptRoot\altcodecs_files.txt -InputObject " " -Encoding utf8 -Append
    Write-Host "$($trans_rei_sp.length) streams: $($trans_vid_sp.length) video, $($trans_aud_sp.length) audio, $($trans_sub_sp.length) sub."
}

Write-Host "`r`nDONE." -ForegroundColor Green
Set-Location $PSScriptRoot
Pause
