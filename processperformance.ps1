#requires -version 3

param(
    [Parameter(Mandatory=$true)]
    [string]$outfile,
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path -Path $_ -Pathtype Container})]
    [string]$InPath,
    [Parameter(Mandatory=$true)]
    [ValidateRange(0,1)] 
    [int]$write
)
$bla = Get-ChildItem -Path $InPath -Recurse -File | ForEach-Object {
    [PSCustomObject]@{
        FullName = $_.FullName
        Name = $_.Name
        HashA = "ZYX"
        HashB = "ZYX"
        HashC = "ZYX"
    }
}

# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

$bla = $bla | Sort-Object -Property FullName
$bla | Out-Null
$MT = @(1,2,4,6,8,12,16,24)


[array]$date = @()
[array]$process = @()
[array]$speed = @()

Write-Host "Running processperformance.ps1" -ForegroundColor Cyan
Start-Sleep -Seconds 5

$date+= Get-Date -Format "dd.MM.yy HH:mm:ss"
$process += "For-loop"
$sw = [diagnostics.stopwatch]::StartNew()
for($i=0; $i -lt $bla.Length; $i++){
    $bla[$i].HashA = Get-FileHash -Path $bla[$i].FullName -Algorithm SHA1 | Select-Object -ExpandProperty Hash
}
$speed += $sw.Elapsed.TotalSeconds
$sw.reset()

for($threadcount=0; $threadcount -lt $MT.Length; $threadcount++){
    start-sleep -Seconds 5
    $date += Get-Date -Format "dd.MM.yy HH:mm:ss"
    $process += "Job ($($MT[$threadcount]))"
    $sw.start()

    # DEFINITION: Split the array:
    Function Split-Input(){
        <#
            .SYNOPSIS
                Splits arrays into X parts.
            .DESCRIPTION
                Adds a PSCustomObject .SplitPart to your array.
            .NOTES
                Version:    1.0
                Author:     flolilo
                Date:       2017-09-17

            .PARAMETER dividend
                The array that will be split.
            .PARAMETER divisor
                In how many parts it will be split.
        #>
        param(
            [Parameter(Mandatory=$true)]
            [array]$dividend,
            [ValidateRange(1,512)]
            [int]$divisor = 1
        )
        # Add a new PSCustomObject to the input-array:
        $dividend | Add-Member -MemberType NoteProperty -Name SplitPart -Value 0
        $dividend | Out-Null

        for($i=1; $i -lt $divisor; $i++){
            for($j=0; $j -lt $dividend.Length; $j++){
                if($j -in (0..[math]::Floor(((1 * ($dividend.Length - 1)) / $divisor)))){
                    $dividend[$j].SplitPart = 0
                }elseif($j -in ([math]::Floor(((($i * ($dividend.Length - 1)) / $divisor) + 1))..[math]::Floor(((($i + 1) * ($dividend.Length - 1))) / $divisor))){
                    $dividend[$j].SplitPart = $i
                }
            }
        }
        # Debug:
        # $dividend | Format-Table -AutoSize

        return $dividend
    }

    $bla = (Split-Input -dividend $bla -divisor $MT[$threadcount])

    for($i=0; $i -lt $MT[$threadcount]; $i++){
        $array = $bla | Where-Object {$_.SplitPart -eq $i}
        Start-job -Name "test_$i" -ScriptBlock {
            param([array]$xy)
            for($i=0; $i -lt $xy.Length; $i++){
                $xy[$i].hashB = Get-FileHash -Path $xy[$i].fullname -Algorithm SHA1 | Select-Object -ExpandProperty Hash
            }
            return $xy
        } -ArgumentList (,$array) | Out-Null
    }

    # Wait-Job -name "test_*" | Out-Null

    [array]$bla = @()
    for($i=0; $i -lt $MT[$threadcount]; $i++){
        $bla += Receive-Job -Wait -AutoRemoveJob -Name "test_$i" | Select-Object -Property * -ExcludeProperty RunspaceId,SplitPart
    }
    # Get-Job | Remove-Job | Out-Null
    $speed += $sw.Elapsed.TotalSeconds
    $sw.reset()
    Start-Sleep -Seconds 5

    $date += Get-Date -Format "dd.MM.yy HH:mm:ss"
    $process += "RSJob ($($MT[$threadcount]))"
    $sw.start()
    $bla | Start-RSJob -Name "GetHash" -throttle $MT[$threadcount] -ScriptBlock {
        $_.HashC = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA1 | Select-Object -ExpandProperty Hash
    } | Wait-RSJob | Receive-RSJob
    Get-RSJob -Name "GetHash" | Remove-RSJob
    $speed += $sw.Elapsed.TotalSeconds
    $sw.reset()
}

[array]$results = @()
for($i=0; $i -lt $date.Length; $i++){
    $verifiedObject = New-Object PSObject
    $verifiedObject | Add-Member -MemberType NoteProperty -Name "Date" -Value $date[$i]
    $verifiedObject | Add-Member -MemberType NoteProperty -Name "Process" -Value $process[$i]
    $verifiedObject | Add-Member -MemberType NoteProperty -Name "Speed" -Value $speed[$i]
    $results += $verifiedObject
}
$results | Export-Csv -Path "$($PSScriptRoot)\$($outfile).csv" -NoTypeInformation -Encoding UTF8
