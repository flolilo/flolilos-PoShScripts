# TODO: Nix.
# Nothing today...
[array]$userIn = "Z:\filme"
$userIn += "Z:\filme_EN"
$userIn += "Z:\serien_DE"
$userIn += "Z:\serien_EN"
$userIn += "Z:\dokus"

for($j=0; $j -lt $userIn.Length; $j++){
    Set-Location $($userIn[$j])
    Write-Host "Looking for files in $($userIn[$j])" -ForegroundColor Yellow
    Get-Childitem $userIn[$j] -Recurse -Exclude *.avi, *.mkv, *.mp4, *.mpg, *.pdf, *.jpg, *.png, *.txt, *.nfo, *.xml | Where-Object {-not $_.PSIsContainer} | Group-Object Extension -NoElement | Sort-Object count -desc
}

Pause
