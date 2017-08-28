param(
    [string]$PCname="lappi",
    [string]$ziel="\\192.168.0.2\_Laura\sicherungen",
    [string]$zuSichern=("D:\")
)
#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding
# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

$datum = (Get-Date -Format "yyyy-MM-dd")

if((Test-Path -Path $ziel -PathType Container) -eq $false){
    Write-Host "Kann Server $ziel nicht erreichen - ABBRUCH!" -ForegroundColor Red
    Pause
    Exit
}

if((Test-Path -Path $ziel\$($PCname)_$($datum) -PathType Container) -eq $false){
    New-Item -Path $ziel\$($PCname)_$($datum) -ItemType Directory
    Start-Sleep -Milliseconds 1
}else{
    Write-Host "Verzeichnis $ziel\$($PCname)_$($datum) bereits vorhanden - ABBRUCH!" -ForegroundColor Red
    Pause
    Exit
}

Write-Host "(Get-Date -Format "yyyy.MM.dd - HH:mm:ss") - Starting..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "`"$PSScriptRoot\preventsleep.ps1`" -mode `"process`" -userProcessCount 1 -userProcess `"robocopy`" -shutdown 0" -WindowStyle Hidden
Start-Process robocopy -ArgumentList " `"$zuSichern`" `"$ziel\$($PCname)_$($datum)`" /r:15 /w:5 /z /mir /v /tee /log:`"$ziel\$($PCname)_$($datum).txt`" " -NoNewWindow -Wait
Write-Host "(Get-Date -Format "yyyy.MM.dd - HH:mm:ss") - Done!" -ForegroundColor Green
Pause
