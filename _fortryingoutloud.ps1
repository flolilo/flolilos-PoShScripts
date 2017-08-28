#DEFINITION: Hopefully avoiding errors by wrong encoding now:
$OutputEncoding = New-Object -typename System.Text.UTF8Encoding
# Get all error-outputs in English:
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

<# DEFINITION: Show all colors (DarkMagenta doesn't work)
    Function Start-ColorSheet(){
        $allColors = ("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","Darkgray","Gray","DarkYellow","White")
        Write-Host " "
        foreach($color in $allColors){
            Write-Host "                                    " -BackgroundColor $color -NoNewline; Write-Host " $color"
            Write-Host " "
        }
        Write-Host " "
        Write-Host " "

        foreach($color in $allColors){
            Write-Host "Das ist ein Testtext ABCDEFGH 123456 " -ForegroundColor $color -NoNewline; Write-Host $color
            Write-Host " "
        }
        Pause
    }

    Start-ColorSheet
#>

<# DEFINITION: testing literal paths for brakcets n stuff...
    Clear-Host
    $recurse = $true
    $bla = 'D:\Temp\bla [ ] pfad'
    $paraInput = $bla
    # $paraInput = $paraInput.Replace('`','``').Replace("[",'``[').Replace("]",'``]')
    # $paraInput = $paraInput -replace '[[+]*?()\\.]','\$&'
    [array]$x = Get-ChildItem -LiteralPath $paraInput -Recurse:$recurse -Directory | ForEach-Object {$_.FullName}
    #$y = $x | % {$_.Replace("````",'`')} | % {$_.Replace("``",'``').Replace("[",'``[').Replace("]",'``]').Replace("'",'`''').Replace("!",'`!').Replace(",",'`,').Replace(";",'`;')}
    # $y = $x -replace "````",'`' -replace ("``",'``') -replace ("[",'``[') -replace ("]",'``]') -replace ("'",'`''') -replace ("!",'`!') -replace (",",'`,') -replace (";",'`;')

    $y = $x -replace '[[+*?()\\.]','\$&'
    # Write-Host $y -BackgroundColor Gray -ForegroundColor Black

    # DEFINITION:
    Write-Host "Original:" -ForegroundColor Cyan
    Write-Host "$paraInput`r`n" -ForegroundColor DarkRed
    try{
        Push-Location -LiteralPath $paraInput -StackName Blubb
        (Get-Item -Path ".\" -Verbose).FullName
        Get-ChildItem * -Recurse:$recurse | ForEach-Object {Write-Host "$($_.Name)`t- " -NoNewline -ForegroundColor Cyan; Write-Host $_.Attributes -ForegroundColor Yellow}
    }
    catch{Write-Host "Push-Location gescheitert." -ForegroundColor DarkCyan -BackgroundColor Gray}
    Pop-Location -StackName Blubb


    # DEFINITION:
    Write-Host "`r`nAbleitung:" -ForegroundColor Cyan
    for($i = 0; $i -lt $y.Length; $i++){
        Write-Host " "
        Write-Host $y[$i] -ForegroundColor Darkcyan
        try{
            Push-Location -LiteralPath "$($y[$i])" -StackName Blubb
            (Get-Item -Path ".\" -Verbose).FullName
            Get-ChildItem * -Recurse:$recurse | ForEach-Object {Write-Host "$($_.FullName)`t- " -NoNewline -ForegroundColor Red; Write-Host "$($_.BaseName)`t- " -NoNewline -ForegroundColor Cyan; Write-Host $_.Attributes -ForegroundColor Yellow}
            Pop-Location -StackName Blubb
        }
        catch{Write-Host "Push-Location gescheitert." -ForegroundColor DarkCyan -BackgroundColor Gray}
    }
    # Pause


    # DEFINITION:
    <#
    Write-Host "`r`nMIT" -ForegroundColor Green
    for($i = 0; $i -lt $y.Length; $i++){
        Write-Host $y[$i] -ForegroundColor Cyan
        Write-Host "Hash mit: " $(Get-FileHash -Path $y[$i] -Algorithm MD5 | % {$_.Hash})
        Write-Host "GCI:"
        Get-ChildItem -Path $y[$i] -Verbose | % {Write-Host "$($_.Name)`t-`t" -NoNewline; Write-Host $_.Attributes}
        Write-Host " "
    }
    #>
    Write-Host " "
    Set-Location $PSScriptRoot
#>

<# DEFINITION: Testing speed of different file-copy-methods:
Write-Host Measure-Command{Start-Process powershell -ArgumentList ""}

Function Start-FileCopy(){


    if($script:secondattempt -eq 0){
        Write-Host " (First attempt to copy)" -ForegroundColor Cyan
        [array]$script:outfile_path = @()
        [array]$inter = @()
        [array]$interfolder = @()
        for($i=0; $i -lt $script:copyfile_path.Length; $i++){
            # prepare output-path-var for subfolder-choice:
            if($script:OutputSubfolderStyle -eq "none"){
                $scriptpathvar = "$($script:OutputPath)"
            }else{
                $scriptpathvar = "$($script:OutputPath)\$($script:copyfile_date_sub[$i])"
            }
            # Test if there's already a file with same name in the output-folder:
            if((Test-Path -Path "$scriptpathvar\$($script:copyfile_name[$i])") -eq $false){
                if($script:debug -ne 0){Write-Host "`r`n$($script:copyfile_name[$i])" -NoNewline; Write-Host "`t- File 404" -ForegroundColor Green -NoNewline}
                $inter = @("$scriptpathvar\$($script:copyfile_basename[$i])")
                $j = 1
                while($true){
                    if($inter -in $script:outfile_path){
                        if($script:debug -ne 0){Write-Host " - $($j - 1) (already in variable)" -NoNewline}
                        $inter = @("$scriptpathvar\$($script:copyfile_basename[$i])_folder$j")
                        $j++
                        continue
                    }else{
                        if($script:debug -ne 0){Write-Host " - $($j - 1) (Original)" -NoNewline}
                        $script:outfile_path += $inter
                        Break
                    }
                }
            }Else{
                # if there is already a file with the same name, append "copyXY" behind it (also checks if "copy1", etc. already exists):
                if($script:debug -ne 0){Write-Host "`r`n$($script:copyfile_name[$i])" -NoNewline; Write-Host "`t- File Found" -ForegroundColor Magenta -NoNewline}
                $j = 1
                while($true){
                    if((Test-Path -Path "$scriptpathvar\$($script:copyfile_basename[$i])_copy$j$($script:copyfile_ext[$i])") -eq $false){
                        $inter = @("$scriptpathvar\$($script:copyfile_basename[$i])_copy$j")
                        if(!($inter -in $script:outfile_path)){
                            if($script:debug -ne 0){Write-Host " - copy$j okay." -NoNewline}
                            $script:outfile_path += $inter
                            break
                        }else{
                            $k = 1
                            while($true){
                                $interfolder = @("$scriptpathvar\$($script:copyfile_basename[$i])_copy$($j)_folder$k")
                                if(!($interfolder -in $script:outfile_path)){
                                    if($script:debug -ne 0){Write-Host " - copy$j folder$k okay." -NoNewline}
                                    $script:outfile_path += $interfolder
                                    break
                                }else{
                                    if($script:debug -ne 0){Write-Host " - copy$j folder$k already in variable." -NoNewline}
                                    $k++
                                    continue
                                }
                            }
                            break
                        }
                    }Else{
                        if($script:debug -ne 0){Write-Host " - copy$j also on HDD." -NoNewline}
                        $j++
                        Continue
                    }
                }
            }
        }
        Write-Host " "
        if($script:debug -ne 0){
            for($i = 0; $i -lt $script:outfile_path.Length; $i++){
                if($($script:outfile_path[$i]) -like "*_copy*"){
                    if($($script:outfile_path[$i]) -like "*_folder*"){
                        Write-Host $script:outfile_path[$i] -ForegroundColor Cyan
                    }else{
                        Write-Host $script:outfile_path[$i] -ForegroundColor Yellow
                    }
                }elseif($($script:outfile_path[$i]) -like "*_folder*"){
                        Write-Host $script:outfile_path[$i] -ForegroundColor Cyan
                }else{
                    Write-Host $script:outfile_path[$i]
                }
            }
        }
        Invoke-Pause
    }else{
        Write-Host " (Second attempt to copy)" -ForegroundColor Cyan
        for($i=0; $i -lt $script:copyfile_path.Length; $i++){
            if($i -in $script:brokenfile_index){
                Remove-Item -Path "$($script:outfile_path[$i])_broken"
            }
        }
    }
    # Only allow 4 instances of xcopy simultaneously:
    $Processcompensation = @(Get-Process -ErrorAction SilentlyContinue -Name xcopy).count
    $activeProcessCounter = 0
    for($i = 0; $i -lt $script:copyfile_path.Length; $i++){
        if($script:secondattempt -eq 1){
            $script:outfile_path[$i] = $($script:outfile_path[$i]).Substring(0, $($script:outfile_path[$i]).lastIndexOf('.'))
        }
        if(($script:secondattempt -eq 1 -and $i -in $script:brokenfile_index) -or ($script:secondattempt -eq 0)){
            while($activeProcessCounter -ge 4){
                $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name xcopy).count - $Processcompensation
                Start-Sleep -Milliseconds 75
            }
            Write-Host "$($i + 1)/$($script:copyfile_path.Length): " -NoNewLine
            $inter = ($($script:copyfile_path[$i]).Replace($script:InputPath,'.')) + "`t"
            Write-Host $inter -NoNewLine -ForegroundColor Cyan
            Write-Host "-> "  -NoNewLine
            $inter = ($($script:outfile_path[$i]).Replace($script:OutputPath,'.')) + $($script:copyfile_ext[$i])
            Write-Host $inter -ForegroundColor Yellow
            Start-Process xcopy -ArgumentList "`"$($script:copyfile_path[$i])`" `"$($script:outfile_path[$i]).*`" /q /i /j /-y" -WindowStyle Hidden
            Start-Sleep -Milliseconds 1
            $activeProcessCounter++
        }
    }
    for($i = 0; $i -lt $script:copyfile_path.Length; $i++){
        if($script:secondattempt -eq 1 -and $i -in $script:brokenfile_index -or $script:secondattempt -eq 0){
            $script:outfile_path[$i] = "$($script:outfile_path[$i])$($script:copyfile_ext[$i])"
        }
    }
    # When finished copying, wait until all xcopy-instances are done:
    while($activeProcessCounter -gt 0){
        $activeProcessCounter = @(Get-Process -ErrorAction SilentlyContinue -Name xcopy).count
        Start-Sleep -Milliseconds 75
    }
    Start-Sleep -Seconds 5
}

Write-Host Measure-Command{}
#>


<# DEFINITION: MKVtoolnix' way for merging Charmed-MKVs with their subtitles
    $vid_in = @(Get-ChildItem -Path "Z:\serien_DE\Charmed_(1998)\Season_08" -Filter "*.mkv" | ForEach-Object {$_.FullName} | Sort-Object $_)
    $vid_out = @($vid_in | ForEach-Object {$_.Replace('.mkv','_DONE.mkv')})
    $sub_eng = @(Get-ChildItem  -Path "D:\Eigene_Videos\MakeMKV\CHARMED_for_subs\Season_08" -Filter "*_ENG.srt" | ForEach-Object {$_.FullName} | Sort-Object $_)
    $sub_ger = @(Get-ChildItem  -Path "D:\Eigene_Videos\MakeMKV\CHARMED_for_subs\Season_08" -Filter "*_GER.srt" | ForEach-Object {$_.FullName} | Sort-Object $_)


    for($i = 0; $i -lt $vid_in.Length; $i++){
        Write-Host $vid_in[$i]
        Write-Host $vid_out[$i] -ForegroundColor Yellow
        Write-Host $sub_eng[$i]
        Write-Host $sub_ger[$i] -ForegroundColor Yellow

        Start-Process -FilePath "D:\Downloads\Sonstiges\Programme\Video_minitools\DVD_tools\mkvtoolnix\mkvmerge.exe" -ArgumentList "--ui-language en --output `"$($vid_out[$i])`" --language 0:und --language 1:eng --default-track 1:yes --language 2:ger `"(`" `"$($vid_in[$i])`" `")`" --language 0:eng --default-track 0:no `"(`" `"$($sub_eng[$i])`" `")`" --language 0:ger --default-track 0:no `"(`" `"$($sub_ger[$i])`" `")`" --track-order 0:0,0:1,0:2,1:0,2:0" -NoNewWindow -Wait

        Remove-Item -Path $vid_in[$i]
        Start-Sleep -Milliseconds 5
        Rename-Item -Path $vid_out[$i] -NewName $vid_in[$i]
    }

    Pause
#>

<# DEFINITION: test special character recognition:
    $bla = Get-ChildItem -Path $PSScriptRoot -Filter "*.ps1" | ForEach-Object {$_.FullName}
    if ($bla -match '[$*:[]?^\/{}|]'){
        write-host "MATCH" -ForegroundColor Red
    }else{
        Write-Host "PASS" -ForegroundColor Green
    }
    Pause
#>

<# DEFINITION: replace sth. between two strings:
    [string]$bla = "blabla" # bla
    $hallo = "haallo"
    $lines_old = Get-Content $PSCommandPath
    $lines_new = $lines_old
    # remember input-path
    if($script:RememberInPath -ne 0){
        Write-Host "From:`t" -NoNewline
        Write-Host $lines_new[(245..249)] -ForegroundColor Gray
        $lines_new[(245..249)] = $lines_new[(245..249)] -replace '\[string\]\$bla\ =\ .*?(\ #\ )',"$('[string]$bla = "' + $hallo + '" # ')"
        Write-Host "To:`t" -NoNewline
        Write-Host $lines_new[(245..249)] -ForegroundColor Yellow
        #$lines_new | Set-Content $PSCommandPath -Encoding UTF8
        #start-sleep -Milliseconds 10
    }
    if($lines_new -like $lines_old){
        Write-Host "SAVING" -ForegroundColor Red
        #Set-Content -Path $PSCommandPath -Value $lines_new -Encoding UTF8
    }else{
        Write-Host "SAME LINES" -ForegroundColor Green
    }
#>

<# DEFINITION: 7z tryout:
    $bla = @(Get-ChildItem -Path "D:\Temp\in ( ) pfad" -Recurse -File | % {$_.FullName})
    Start-Process 7z -ArgumentList ""
#>

<# DEFINITION: trying to figure out RSJob:
    if (-not (Get-Module -ListAvailable -Name PoshRSJob)){
        Write-Host "Module RSJob (https://github.com/proxb/PoshRSJob) is required, but it seemingly isn't installed - please start PowerShell as administrator and run`t" -ForegroundColor Red -NoNewline
        Write-Host "Install-Module -Name PoshRSJob" -ForegroundColor DarkYellow
        Exit
    }

    $timer = [diagnostics.stopwatch]::StartNew()
    $bla_job = @()
    $bla_job += Get-ChildItem -Path "D:\Eigene_Bilder\_CANON\2017-07-28_08-14 (Urlaub Albanien)" -Filter *.jpg -Recurse | ForEach-Object {
    # $bla += Get-ChildItem -Path "D:\Desktop" -Filter *.docx | ForEach-Object {
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            Size = $_.Length
            Hash = "XYZ"
        }
    }

    $bla_job | Start-RSJob -Throttle 4 -ScriptBlock {
        $_.hash = Get-FileHash -Path $_.FullName -Algorithm SHA1 | Select-Object -ExpandProperty Hash
    } | Wait-RSJob -ShowProgress | Receive-RSJob

    Get-RSJob | Remove-RSJob
    $timer.stop()
    $time_job = $timer.Elapsed.TotalSeconds

    $timer.reset()
    $timer.start()
    $bla_ind = @()
    $bla_ind += Get-ChildItem -Path "D:\Eigene_Bilder\_CANON\2017-07-28_08-14 (Urlaub Albanien)" -Filter *.jpg -Recurse | ForEach-Object {
        # $bla += Get-ChildItem -Path "D:\Desktop" -Filter *.docx | ForEach-Object {
        [PSCustomObject]@{
            FullName = $_.FullName
            BaseName = $_.BaseName
            Size = $_.Length
            Hash = Get-FileHash -Path $_.FullName -Algorithm SHA1 | Select-Object -ExpandProperty Hash
        }
    }

    $timer.stop()
    $time_ind = $timer.Elapsed.TotalSeconds

    for($i = 0; $i -lt $bla_job.Length; $i++){
        Write-Host $bla_job[$i].BaseName -ForegroundColor Cyan -NoNewline
        Write-Host "`t" -NoNewline
        Write-Host $bla_job[$i].Size -ForegroundColor Cyan -NoNewline
        Write-Host "`t" -NoNewline
        Write-Host $bla_job[$i].Hash -ForegroundColor Cyan
        Write-Host $bla_ind[$i].BaseName -ForegroundColor Yellow -NoNewline
        Write-Host "`t" -NoNewline
        Write-Host $bla_ind[$i].Size -ForegroundColor Yellow -NoNewline
        Write-Host "`t" -NoNewline
        Write-Host $bla_ind[$i].Hash -ForegroundColor Yellow}

    Write-Host "`r`nTime for RSJob:`t$time_job`tseconds." -ForegroundColor Cyan
    Write-Host "Time for indiv:`t$time_ind`tseconds." -ForegroundColor Yellow

    Write-Host "Differences:" -ForegroundColor Yellow
    $vergleich = (Compare-Object -ReferenceObject $bla_ind -DifferenceObject $bla_job -Property hash,Size,FullName -PassThru).Path
    Write-Host $vergleich.Length
    Write-Host $vergleich
#>

# DEFINITION: Messing around with Write-ColorOut and Write-Host:
    Function Write-ColorOut(){
        <#
            .SYNOPSIS
                A faster version of Write-Host
            
            .DESCRIPTION
                Using the [Console]-commands to make everything faster.

            .NOTES
                Date: 2018-08-22
            
            .PARAMETER Object
                String to write out
            
            .PARAMETER ForegroundColor
                Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
            
            .PARAMETER BackgroundColor
                Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
            
            .PARAMETER NoNewLine
                When enabled, no line-break will be created.
            
            .EXAMPLE
                Write-ColorOut "Hello World!" -ForegroundColor Green -NoNewLine
        #>
        param(
            [string]$Object,
            [string]$ForegroundColor=[Console]::ForegroundColor,
            [string]$BackgroundColor=[Console]::BackgroundColor,
            [switch]$NoNewLine=$false
        )
        $old_fg_color = [Console]::ForegroundColor
        $old_bg_color = [Console]::BackgroundColor
        
        if($ForeGroundColor -ne $old_fg_color){[Console]::ForegroundColor = $ForeGroundColor}
        if($BackgroundColor -ne $old_bg_color){[Console]::BackgroundColor = $BackgroundColor}

        if($NoNewLine -eq $false){
            [Console]::WriteLine($Object)
        }else{
            [Console]::Write($Object)
        }
        
        if($ForeGroundColor -ne $old_fg_color){[Console]::ForegroundColor = $old_fg_color}
        if($BackgroundColor -ne $old_bg_color){[Console]::BackgroundColor = $old_bg_color}
    }

    start-sleep -Milliseconds 500

    $i=0
    $sw = [diagnostics.stopwatch]::StartNew()
    while($i -lt 100){
        Write-ColorOut "Gelb`tGelb","Rot`tRot" -ForegroundColor "Yellow" -NoNewLine
        Write-ColorOut " test"
        $i++
    }
    $sw.stop()
    $colorout = $sw.Elapsed.TotalMilliseconds
    $sw.reset()

    start-sleep -Milliseconds 500

    $i=0
    $sw.start()
    while($i -lt 100){
        Write-Host "Gelb`tGelb","Rot`tRot" -ForegroundColor "Yellow" -NoNewLine
        Write-Host " test"
        $i++
    }
    $sw.stop()
    $whost = $sw.Elapsed.TotalMilliseconds
    $sw.reset()

    Write-ColorOut "$colorout vs $whost" -ForegroundColor Red
#>


<# DEFINITION: fooling around with progresses and stuff:
    $i = 1
    $timer = [diagnostics.stopwatch]::StartNew()

    $sw = [diagnostics.stopwatch]::StartNew()
    # $sw.Start()

    $bla = Get-ChildItem -Path D:\Eigene_Bilder\_CANON -Recurse -Filter *.jpg | Select-Object -ExpandProperty FullName | ForEach-Object {
        # Get-FileHash -Path $_.FullName -Algorithm SHA1
        if($sw.Elapsed.TotalMilliseconds -ge 125 -or $i -eq 1){
            Write-Progress -Activity "Getting Child-Items:" -PercentComplete -1 -Status "File # $i"
            $sw.Reset()
            $sw.Start()
        }
        $i++
        Write-ColorOut $_
    }
    $sw.Stop()

    $timer.Stop()
    $time = $timer.Elapsed.TotalSeconds
    Write-Output $time
#>
