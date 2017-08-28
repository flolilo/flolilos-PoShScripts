# Flo's Foobar-MP3-Copy-Script
# Delete subfolders that only contain XMP or INI
param(
    [string]$paraInput="D:\Eigene_Bilder\_CANON",
    [string]$catalog_folder="_Picture_Catalogs",
    [array]$extensions=(
        "*.cr2",
        "*.dng",
        "*.jp2",
        "*.jpeg",
        "*.jpg",
        "*.jxr",
        "*.mkv",
        "*.mov",
        "*.mp4",
        "*.nrw",
        "*.psb",
        "*.psd",
        "*.tif",
        "*.tiff"
    )
)

Clear-Host

if((Test-Path -Path $paraInput -PathType Container) -eq $false){
    Write-Host "FOLDER NON-EXISTENT!" -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

$subfolders = Get-ChildItem -Path $paraInput -Exclude $catalog_folder -Directory | Select-Object -ExpandProperty FullName
for($i = 0; $i -lt $subfolders.Length; $i++){
    $files = 0
    foreach($j in $extensions){
        $files += (Get-ChildItem -Path $subfolders[$i] -Filter $j -File -Recurse).count
    }
    if($files -eq 0){
        Write-Host "DELETE $($subfolders[$i])" -ForegroundColor Red
        Get-ChildItem -Path $subfolders[$i] -File -Recurse | Group-Object Extension -NoElement | Sort-Object Count -Descending
        if((Read-Host "`r`nReally delete this folder? 1 for yes, else for no") -eq 1){
            Remove-Item -Path $subfolders[$i] -Recurse
        }
    }else{
        Write-Host "KEEP $($subfolders[$i])" -ForegroundColor Green
    }
}

Pause
