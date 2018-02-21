#requires -version 3

<#
    .SYNOPSIS
        Automount SMB devices.
    .DESCRIPTION
        Use "net use" to connect shares that are specified in a JSON-file.
    .NOTES
        Version:    1.1
        Date:       2017-10-31
        Author:     flolilo
        Note:       Script is free to use - no warranties, user is responsible for any effect the script has.

    .INPUTS
        automount_smb_vars.json (UTF-8 encoded):
        {
            "presetname": "foobar",
            "settings": {
                "username": "users\\foobar",
                "shares": [
                    "\\\\192.168.0.2\\foobar",
                    "\\\\10.0.0.20\\foobar",
                ]
            }
        }
        you can add "password" in "settings" if you want to, then include it in the ForEach-Object command.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$user
)
# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

[array]$alphabet = @()
for([byte]$char=[char]'Z'; $char -ge [char]'A'; $char--){
    $alphabet += [char]$char
}

try{
    $JSONFile = Get-Content -Path "$($PSScriptRoot)\automount_smb_vars.json" -Raw -Encoding UTF8 | ConvertFrom-Json
}catch{
    Write-Host "Could not load $($PSScriptRoot)\automount_smb_vars.json." -ForegroundColor Red
    Start-Sleep -Seconds 5
    Exit
}
$JSONFile | Out-Null

$uservars = $JSONFile | Where-Object {$_.presetname -eq $user} | ForEach-Object {
    [PSCustomObject]@{
        user = $_.settings.username
        password = Read-Host "Enter your password, please`t"
        # password = $_.settings.password # | ConvertTo-SecureString -AsPlainText -Force # CREDIT: https://stackoverflow.com/a/6240319/8013879
        shares = @($_.settings.shares)
    }
}
<# DEFINITION: Trying to merge in New-PSDrive
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $uservars.user, $uservars.password
    New-PSDrive -Name "Z" -Root $uservars.shares[0] -PSProvider FileSystem -Persist:$true -Credential $cred -Verbose
#>
<#
    for($i=0; $i -lt $uservars.shares.Length; $i++){
        if((Test-Path -Path $uservars.shares[$i] -PathType Container -ErrorAction SilentlyContinue) -eq $false){
            Write-Host "Cannot find $($uservars.shares[$i])." -ForegroundColor DarkRed
            Start-Sleep -Seconds 2
            $uservars.shares = $uservars.shares | Where-Object {$_ -ne $uservars.shares[$i]}
        }
    }
#>

[int]$j=0
for($i=0; $i -lt $alphabet.Length -and $j -lt $uservars.shares.Length; $i++){
    if((Test-Path -Path "$($alphabet[$i]):\" -ErrorAction SilentlyContinue) -eq $false){
        try{
            Start-Process cmd -ArgumentList "/c net use $($alphabet[$i]): $($uservars.shares[$j]) /user:$($uservars.user) $($uservars.password) /persistent:no" -NoNewWindow -Wait
            Write-Host "Connected $($uservars.shares[$j]) to $($alphabet[$i])." -ForegroundColor DarkGreen
            $j++
        }catch{
            Write-Host "Connecting $($uservars.shares[$j]) to $($alphabet[$i]) failed!" -ForegroundColor DarkRed
        }
    }
}
if($j -lt ($uservars.shares.Length -1)){
    Write-Host "Some connections were not made..." -ForegroundColor DarkRed
}

Write-Host "Done." -ForegroundColor Green

Clear-Variable * -Scope Script -ErrorAction SilentlyContinue
Clear-Variable * -Scope Local -ErrorAction SilentlyContinue
