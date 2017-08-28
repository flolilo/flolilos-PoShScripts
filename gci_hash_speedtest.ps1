# DEFINITION: Measures time taken to Get-Childitem and to Get-Filehashes (each algorithm separately)

[array]$script:text = @("`r`n PS Version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.Build).$($PSVersionTable.PSVersion.Revision)`r`n")

Start-Process powershell -Argumentlist "Write-VolumeCache d" -Wait -WindowStyle Hidden
Start-Sleep -Seconds 5

for($i = 1; $i -le 6; $i++){
    Write-Host $i
    $script:gci = (Measure-Command{$script:paths = Get-Childitem -Path "D:\Downloads" -Directory:$false -Recurse | ForEach-Object {$_.FullName}}).TotalMilliseconds
    if($i -gt 3){Start-Process powershell -Argumentlist "Write-VolumeCache d" -Wait -WindowStyle Hidden}
    Write-Host "GCI: $script:gci"
    Start-Sleep -Seconds 5
    $script:md5 = (Measure-Command{$script:paths | ForEach-Object {Get-FileHash -Path "$($_)" -Algorithm MD5}}).TotalMilliseconds
    if($i -gt 3){Start-Process powershell -Argumentlist "Write-VolumeCache d" -Wait -WindowStyle Hidden}
    Write-Host "MD5: $script:md5"
    Start-Sleep -Seconds 5
    $script:sha1 = (Measure-Command{$script:paths | ForEach-Object {Get-FileHash -Path "$($_)" -Algorithm SHA1}}).TotalMilliseconds
    if($i -gt 3){Start-Process powershell -Argumentlist "Write-VolumeCache d" -Wait -WindowStyle Hidden}
    Write-Host "SHA1: $script:sha1"
    Start-Sleep -Seconds 5
    $script:text += @("Pass " + $i + "`r`n" + "Items:`t" + $script:paths.Length + "`r`n" + "GCI:`t" + $script:gci + "`r`n" + "MD5:`t" + $script:md5 + "`r`n" + "SHA1:`t" + $script:sha1 + "`r`n" )
    Start-Sleep -Milliseconds 500
}

$script:text | Out-File -FilePath "$PSScriptRoot\hash_speed.txt" -Encoding utf8 -Append
$script:text | Write-Host
