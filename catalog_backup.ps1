#requires -version 3

<#
    .SYNOPSIS
        Script to back up/sync catalog(s) of Phase One's Capture One and Adobe's Lightroom.

    .DESCRIPTION
        Using 7z to fastly archive the catalog(s) to the backup-location, using robocopy to download the archive from the backup-location.

    .INPUTS
        None
    .OUTPUTS
        None

    .NOTES
        Version:        0.1
        Author:         flolilo
        Creation Date:  2017-08-18 (GitHub release)

    .PARAMETER upDown
        Defines if catalogs will be backed up or if backup will be restored. Choice: "up" or "down".
    .PARAMETER toProcess
        Which catalog(s) are to process. Choice: LR, C1, or both ("LR","C1")
    .PARAMETER LR_path
        Path to Lightroom's catalog
    .PARAMETER C1_path
        Path to Capture One's catalog
    .PARAMETER server_path
        Path to backup location
    .PARAMETER 7zipexe
        Path to 7z.exe
    .PARAMETER 7z_up_prefix
        Beginning of 7zip command code (upstream)
    .PARAMETER 7z_up_suffix
        Ending of 7z command code (upstream)
    .PARAMETER 7z_down_prefix
        Beginning of 7zip command code (downstream)
    .PARAMETER 7z_down_suffix
        Ending of 7z command code (downstream)
    .PARAMETER rc_switches
        Robocopy command code switches
    .PARAMETER confirmDelete
        Ask for confirmation of older 7z-archives: 1 to enable confirmation, 0 to disable it.

    .EXAMPLE
        catalog_backup.ps1 -upDown "up" -toProcess "C1" -confirmDelete 1
#>

# TODO: kick out robocopy: just unpack 7z-archive to computer. TODO:
param(
    [string]$upDown="define",
    [array]$toProcess=@(),
    [string]$LR_path="D:\Eigene_Bilder\_CANON\_Picture_Catalogs\Lightroom",
    [string]$C1_path="D:\Eigene_Bilder\_CANON\_Picture_Catalogs\Capture_One",
    [string]$server_path="\\192.168.0.2\_Flo\Eigene_Bilder\_CANON",
    [string]$7zipexe="C:\Program Files\7-Zip\7z.exe",
    [string]$7z_up_prefix="a",
    [string]$7z_up_suffix="-mx=0",
    [string]$7z_down_prefix="x",
    [string]$7z_down_suffix="",
    [string]$rc_switches="/J /R:5 /W:15",
    [int]$confirmDelete=-1
)
#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding
# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'


if($upDown -ne "up" -and $upDown -ne "down"){
    while($true){
        $upDown = Read-Host "Upload or download catalog(s)?"
        if($upDown -ne "up" -and $upDown -ne "down"){
            continue
        }else{
            break
        }
    }
}
if($toProcess.Length -lt 1){
    while($true){
        $separator = ","
        $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $toProcess = (Read-Host "Which catalog(s) to process? Both: `"C1`",`"LR`"").Split($separator,$option)
        if("LR" -notin $toProcess -and "C1" -notin $toProcess){
            Write-Host $toProcess
            continue
        }else{
            break
        }
    }
}
if($confirmDelete -notin (0..1)){
    while($true){
        $confirmDelete = Read-Host "Confirm deletion of old archives / folders? (Integer)"
        if($confirmDelete -notin (0..1)){
            continue
        }else{
            break
        }
    }
}

[switch]$confirm = $(if($confirmDelete -eq 1){$true}else{$false})
$archive_name_lr = "_Picture_Catalog_LR_$(Get-Date -Format "yyyy-MM-dd").7z"
$archive_name_c1 = "_Picture_Catalog_C1_$(Get-Date -Format "yyyy-MM-dd").7z"

if($upDown -eq "up"){  
    if("LR" -in $toProcess){
        Write-Host "Scanning for and removing old LR-backups in $server_path ..." -ForegroundColor Cyan
        Get-ChildItem -Path "$server_path\_Picture_Catalog_LR_*" -Filter *.7z -File | ForEach-Object {
            Remove-Item $_.FullName -Confirm:$confirm
        }
        Start-Sleep -Milliseconds 250
        Write-Host "7zipping new LR-backup to $server_path ..." -ForegroundColor Cyan
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_up_prefix `"$server_path\$archive_name_lr`" `"$LR_path\*`" $7z_up_suffix" -NoNewWindow -Wait
    }
    if("C1" -in $toProcess){
        Write-Host "Scanning for and removing old C1-backups in $server_path ..." -ForegroundColor Cyan
        Get-ChildItem -Path "$server_path\_Picture_Catalog_C1_*" -Filter *.7z -File | ForEach-Object {
            Remove-Item $_.FullName -Confirm:$confirm
        }
        Start-Sleep -Milliseconds 250
        Write-Host "7zipping new C1-backup to $server_path ..." -ForegroundColor Cyan
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_up_prefix `"$server_path\$archive_name_c1`" `"$C1_path\*`" $7z_up_suffix" -NoNewWindow -Wait
    }
}elseif($upDown -eq "down"){
    if("LR" -in $toProcess){
        [array]$archive_LR = Get-ChildItem -Path "$server_path\_Picture_Catalog_LR_*" -Filter *.7z -File | ForEach-Object {
            [PSCustomObject]@{
                fullpath = $_.FullName
                name = $_.Name
            }
        }
        if($archive_LR.Length -gt 1){
            Write-Host "More than one file found:" -ForegroundColor Magenta
            Write-Host $archive_LR.name -ForegroundColor Yellow
            Pause
        }
        Get-ChildItem -Path $LR_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process robocopy -ArgumentList " `"$(Split-Path -Path $archive_LR.fullpath -Parent)`" `"$LR_path`" `"$($archive_LR.name)`" $rc_switches" -NoNewWindow -Wait
        Get-ChildItem -Path $LR_path -Recurse -Directory | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Confirm:$confirm
        }
        Get-ChildItem -Path $LR_path -Recurse -File -Exclude *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_down_prefix `"$LR_path\$($archive_LR.name)`" -o`"$LR_path`" $7z_down_suffix" -NoNewWindow -Wait
        Get-ChildItem -Path $LR_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }

    }
    if("C1" -in $toProcess){
        $archive_C1 = Get-ChildItem -Path "$server_path\_Picture_Catalog_C1_*" -Filter *.7z -File | ForEach-Object {
            [PSCustomObject]@{
                fullpath = $_.FullName
                name = $_.Name
            }
        }
        if($archive_C1.Length -gt 1){
            Write-Host "More than one file found:" -ForegroundColor Magenta
            Write-Host $archive_C1.name -ForegroundColor Yellow
            Pause
        }
        Get-ChildItem -Path $C1_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process robocopy -ArgumentList " `"$(Split-Path -Path $archive_C1.fullpath -Parent)`" `"$C1_path`" `"$($archive_C1.name)`" $rc_switches" -NoNewWindow -Wait
        Get-ChildItem -Path $C1_path -Recurse -Directory | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Confirm:$confirm
        }
        Get-ChildItem -Path $C1_path -Recurse -File -Exclude *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }
        Start-Process -FilePath $7zipexe -ArgumentList "$7z_down_prefix `"$C1_path\$($archive_C1.name)`" -o`"$C1_path`" $7z_down_suffix" -NoNewWindow -Wait
        Get-ChildItem -Path $C1_path -File -Filter *.7z | ForEach-Object {
            Remove-Item -Path $_.FullName -Confirm:$confirm
        }

    }
}
