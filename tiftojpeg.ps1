#requires -version 3

param(
    [string]$InputPath =        "$((Get-Location).Path)",
    [string]$EXIFtool =         "$($PSScriptRoot)\exiftool.exe",
    [string]$Magick =           "C:\Program Files\ImageMagick-7.0.7-Q8\magick.exe",
    [string]$Suffix =           "",
    [ValidateRange(0,1)]
    [int]$RemoveTIF =           1
)

[array]$files = @(Get-ChildItem -Path $InputPath -Filter *.tif | ForEach-Object {
    [PSCustomObject]@{
        FullName = $_.FullName
        BaseName = $(if($Suffix.Length -eq 0){$_.BaseName}else{"$($_.BaseName)_$Suffix"})
        # Extension = $_.Extension
        Directory = Split-Path -Path $_.FullName -Parent
    }
})

$files | Start-RSJob -Name {$_.BaseName} -ArgumentList $EXIFtool,$Magick,$RemoveTIF -ScriptBlock {
    param([string]$EXIFtool,[string]$Magick,[int]$RemoveTIF)
    [string]$inter = "$($_.Directory)\$($_.BaseName).jpg"
    [int]$i = 1
    while($true){
        if(Test-Path -Path $inter -PathType Leaf){
            [string]$inter = "$($_.Directory)\$($_.BaseName)_$($i).jpg"
            $i++
            continue
        }else{
            break
        }
    }
    Start-Process -FilePath $Magick -ArgumentList "convert -quality 92 `"$($_.FullName)`" `"$inter`"" -Wait -WindowStyle Hidden
    Start-Process -FilePath $EXIFtool -ArgumentList " -tagsfromfile `"$($_.FullName)`" -All:All -overwrite_original `"$inter`"" -Wait -WindowStyle Hidden
    if($RemoveTIF -eq 1){
        Remove-Item $_.FullName
    }
} | Wait-RSJob -ShowProgress

Get-RSJob | Stop-RSJob
Get-RSJob | Remove-RSJob
