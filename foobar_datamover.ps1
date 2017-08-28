# Flo's Foobar-MP3-Copy-Script
# Foobar-Strategie: %Artist%\[%Album%\][%Track% - ]Name.mp3
param(
    [string]$paraInput = "D:\Temp\mp3_auto",
    [int]$renameOnly = 0
)

Clear-Host

if((Test-Path -Path $paraInput -PathType Container) -eq $false){
    Write-Host "FOLDER NON-EXISTENT!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

Function Start-Renaming(){
    Write-Host "$(Get-Date -Format "dd.MM.yy - HH:mm") - Renaming files..." -ForegroundColor Cyan
    $renamemp3 = @(Get-ChildItem -Path $script:paraInput -Filter "*.mp3" -Recurse)
    $renamemp3_path = $renamemp3 | ForEach-Object {$_.Directory}
    $renamemp3_name = $renamemp3 | ForEach-Object {$_.Name}
    for($i=0; $i -lt $renamemp3.Length; $i++){
        $old_mp3 = $renamemp3_name[$i]
        $new_mp3 = $old_mp3.Replace('&',"+").Replace("`'","").Replace("ä","ae").Replace("ö","oe").Replace("ü","ue").Replace("ß","ss").Replace(" ", "_")
        if($new_mp3 -notlike $old_mp3){
            Write-Host "Renaming from `"$old_mp3`" to `"$new_mp3`"..." -ForegroundColor Yellow
            try{Rename-Item -Path "$($renamemp3_path[$i])\$old_mp3" -NewName "$($renamemp3_path[$i])\$new_mp3"}
            catch{Write-Host "RENAMING FAILED" -ForegroundColor Red}
        }Else{
            Write-Host "No renaming (`"$old_mp3`" equals `"$new_mp3`")"
        }
    }
    Start-Sleep -Seconds 1

    Write-Host "`r`n$(Get-Date -Format "dd.MM.yy - HH:mm") - Renaming folders..." -ForegroundColor Cyan
    $renamefolder = @(Get-ChildItem -Path $script:paraInput -Directory -Recurse | Sort-Object -Descending Length,FullName)
    $renamefolder_path = Split-Path -Path $renamefolder.FullName -Parent
    $renamefolder_name = $renamefolder | ForEach-Object {$_.BaseName}
    for($i=0; $i -lt $renamefolder.Length; $i++){
        $renamefolder_path = Split-Path -Path $($renamefolder[$i]).FullName -Parent
        $old_folders = $renamefolder_name[$i]
        $new_folders = $old_folders.Replace('&',"+").Replace("`'","").Replace("ä","ae").Replace("ö","oe").Replace("ü","ue").Replace("ß","ss").Replace(" ", "_").Replace(",","")
        if($new_folders -notlike $old_folders){
            Write-Host "Renaming from `"$old_folders`" to `"$new_folders`"..." -ForegroundColor Yellow
            try{Rename-Item -Path "$renamefolder_path\$old_folders" -NewName "$new_folders"}
            catch{Write-Host "RENAMING FAILED" -ForegroundColor Red}
        }Else{
            Write-Host "No renaming (`"$old_folders`" equals `"$new_folders`")"
        }
        Start-Sleep -Milliseconds 1
    }
    Start-Sleep -Seconds 1
}

Function Start-Moving(){
    Write-Host "$(Get-Date -Format "dd.MM.yy - HH:mm") - Moving files..." -ForegroundColor Cyan
    for($loop=0; $loop -lt 2; $loop++){
        [array]$artist =  @(Get-ChildItem -Path $script:paraInput -Directory)
        [array]$artist_path = @($artist | ForEach-Object {$_.FullName})
        [array]$artist_name = @($artist | ForEach-Object {$_.BaseName})
        Write-Host "`r`nLoop $($loop + 1) / 2" -ForegroundColor Cyan
        for($i=0; $i -lt $artist_path.Length; $i++){
            Write-Host "$($artist_name[$i])" -ForegroundColor Red
            [array]$album =  @(Get-ChildItem -Path $($artist_path[$i]) -Directory)
            [array]$album_path = @($album | ForEach-Object {$_.FullName})
            [array]$album_name = @($album | ForEach-Object {$_.BaseName})
            [array]$artist_mp3 = @(Get-ChildItem -Path $($artist_path[$i]) -Filter "*.mp3")
            [array]$artist_mp3_path = @($artist_mp3 | ForEach-Object {$_.FullName})
            [array]$artist_mp3_name = @($artist_mp3 | ForEach-Object {$_.Name})
            foreach($bla in $album_name){Write-Host "|------ $bla" -ForegroundColor Yellow}
            foreach($bla in $artist_mp3_name){Write-Host "|------ $bla"}
            if($album_path.Length -eq 0 -and $artist_mp3_path.Length -eq 0){
                Write-Host "No files in $($artist_path[$i]) - Removing artist-folder..." -ForegroundColor Magenta
                try{Remove-Item -Path $($artist_path[$i]) -Force}
                catch{Write-Host "REMOVING FAILED!" -ForegroundColor Red}
            }elseif($album_path.Length -eq 0 -and $artist_mp3_path.Length -eq 1){
                Write-Host "1 file and no album-folder in $($artist_path[$i]) - Moving file up and removing folder..." -ForegroundColor Yellow
                try{
                    Move-Item -Path $($artist_mp3_path[0]) -Destination (Split-Path -Parent -Path $($artist_path[0]))
                    Start-Sleep -Milliseconds 1
                    Remove-Item -Path $($artist_path[$i]) -Force
                }
                catch{Write-Host "(RE)MOVING FAILED!" -ForegroundColor Red}
            }elseif($album_path.Length -eq 1){
                Write-Host "1 album-folder in $($artist_path[$i]) - Moving files up and removing album-folder..." -ForegroundColor Yellow
                try{
                    Get-ChildItem -Path $album_path[0] | ForEach-Object {Move-Item -Path $_.FullName -Destination (Split-Path -Parent -Path (Split-Path -Parent -Path $_.FullName))}
                    Start-Sleep -Milliseconds 1
                    Remove-Item -Path $album_path[0] -Force
                }
                catch{Write-Host "(RE)MOVING FAILED!" -ForegroundColor Red}
            }elseif($album_path.Length -gt 1){
                for($j = 0; $j -lt $album_path.Length; $j++){
                    [array]$album_mp3 = @(Get-ChildItem -Path $album_path[$j] -Filter "*.mp3")
                    [array]$album_mp3_path = @($album_mp3 | ForEach-Object {$_.FullName})
                    [array]$album_mp3_name = @($album_mp3 | ForEach-Object {$_.Name})
                    foreach($bla in $album_mp3_name){Write-Host "        |-------$bla"}
                    if($album_mp3_path.Length -eq 0){
                        Write-Host "No file in album-folder - removing album-folder..." -ForegroundColor Magenta
                        try{Remove-Item -Path $($album_path[$j]) -Force}
                        catch{Write-Host "REMOVING FAILED!" -ForegroundColor Red}
                    }elseif($album_mp3_path.Length -eq 1){
                        Write-Host "1 File in album-path - Moving files up and removing album-folder..." -ForegroundColor Yellow
                        try{
                            Get-ChildItem -Path $($album_path[$j]) | ForEach-Object {Move-Item -Path $_.FullName -Destination (Split-Path -Parent -Path (Split-Path -Parent -Path $_.FullName))}
                            Start-Sleep -Milliseconds 1
                            Remove-Item -Path $($album_path[$j]) -Force
                        }
                        catch{Write-Host "(RE)MOVING FAILED!" -ForegroundColor Red}
                    }
                    Start-Sleep -Milliseconds 1
                }
            }
        }
        Start-Sleep -Milliseconds 1
    }
}

Start-Renaming
if($renameOnly -eq 0){Start-Moving}

Set-Location $PSScriptRoot
Write-Host "`r`nFERTIG!" -ForegroundColor Green
Pause
