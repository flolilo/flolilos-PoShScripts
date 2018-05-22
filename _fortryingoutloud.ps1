# DEFINITION: Get all error-outputs in English:
    [Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
# DEFINITION: Hopefully avoiding errors by wrong encoding now:
    $OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding
    [Console]::InputEncoding = New-Object -TypeName System.Text.UTF8Encoding

# DEFINITION: Making Write-Host much, much faster:
Function Write-ColorOut(){
    <#
        .SYNOPSIS
            A faster version of Write-Host
        .DESCRIPTION
            Using the [Console]-commands to make everything faster.
        .NOTES
            Date: 2018-05-22
        
        .PARAMETER Object
            String to write out
        .PARAMETER ForegroundColor
            Color of characters. If not specified, uses color that was set before calling. Valid: White (PS-Default), Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkMagenta, DarkBlue
        .PARAMETER BackgroundColor
            Color of background. If not specified, uses color that was set before calling. Valid: DarkMagenta (PS-Default), White, Red, Yellow, Cyan, Green, Gray, Magenta, Blue, Black, DarkRed, DarkYellow, DarkCyan, DarkGreen, DarkGray, DarkBlue
        .PARAMETER NoNewLine
            When enabled, no line-break will be created.

        .EXAMPLE
            Just use it like Write-Host.
    #>
    param(
        [string]$Object = "Write-ColorOut was called, but no string was transfered.",

        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")]
        [string]$ForegroundColor,

        [ValidateSet("DarkBlue","DarkGreen","DarkCyan","DarkRed","Blue","Green","Cyan","Red","Magenta","Yellow","Black","DarkGray","Gray","DarkYellow","White","DarkMagenta")]
        [string]$BackgroundColor,

        [switch]$NoNewLine=$false,

        [ValidateRange(0,48)]
        [int]$Indentation=0
    )

    if($ForegroundColor.Length -ge 3){
        $old_fg_color = [Console]::ForegroundColor
        [Console]::ForegroundColor = $ForegroundColor
    }
    if($BackgroundColor.Length -ge 3){
        $old_bg_color = [Console]::BackgroundColor
        [Console]::BackgroundColor = $BackgroundColor
    }
    if($Indentation -gt 0){
        [Console]::CursorLeft = $Indentation
    }

    if($NoNewLine -eq $false){
        [Console]::WriteLine($Object)
    }else{
        [Console]::Write($Object)
    }
    
    if($ForegroundColor.Length -ge 3){
        [Console]::ForegroundColor = $old_fg_color
    }
    if($BackgroundColor.Length -ge 3){
        [Console]::BackgroundColor = $old_bg_color
    }
}

<# DEFINITION: Speed-test for Write-ColorOut vs. Write-Host
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

<# DEFINITION: Show all console-colors
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


<# DEFINITION: testing literal paths for brackets n stuff...
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

    Write-Host "Original:" -ForegroundColor Cyan
    Write-Host "$paraInput`r`n" -ForegroundColor DarkRed
    try{
        Push-Location -LiteralPath $paraInput -StackName Blubb
        (Get-Item -Path ".\" -Verbose).FullName
        Get-ChildItem * -Recurse:$recurse | ForEach-Object {Write-Host "$($_.Name)`t- " -NoNewline -ForegroundColor Cyan; Write-Host $_.Attributes -ForegroundColor Yellow}
    }
    catch{Write-Host "Push-Location gescheitert." -ForegroundColor DarkCyan -BackgroundColor Gray}
    Pop-Location -StackName Blubb

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

    Write-Host "`r`nMIT" -ForegroundColor Green
    for($i = 0; $i -lt $y.Length; $i++){
        Write-Host $y[$i] -ForegroundColor Cyan
        Write-Host "Hash mit: " $(Get-FileHash -Path $y[$i] -Algorithm MD5 | % {$_.Hash})
        Write-Host "GCI:"
        Get-ChildItem -Path $y[$i] -Verbose | % {Write-Host "$($_.Name)`t-`t" -NoNewline; Write-Host $_.Attributes}
        Write-Host " "
    }

    Write-Host " "
    Set-Location $PSScriptRoot
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


<# DEFINITION: MKVtoolnix' way for merging MKVs with their subtitles
    $vid_in = @(Get-ChildItem -Path "Z:\Videos" -Filter "*.mkv" | Select-Object -ExpandProperty FullName | Sort-Object $_)
    $vid_out = @($vid_in | ForEach-Object {$_.Replace('.mkv','_DONE.mkv')})
    $sub_eng = @(Get-ChildItem  -Path "Z:\Videos" -Filter "*_ENG.srt" | Select-Object -ExpandProperty FullName | Sort-Object $_)
    $sub_ger = @(Get-ChildItem  -Path "Z:\Videos" -Filter "*_GER.srt" | Select-Object -ExpandProperty FullName | Sort-Object $_)


    for($i = 0; $i -lt $vid_in.Length; $i++){
        Write-Host $vid_in[$i]
        Write-Host $vid_out[$i] -ForegroundColor Yellow
        Write-Host $sub_eng[$i]
        Write-Host $sub_ger[$i] -ForegroundColor Yellow

        Start-Process -FilePath ".\mkvmerge.exe" -ArgumentList "--ui-language en --output `"$($vid_out[$i])`" --language 0:und --language 1:eng --default-track 1:yes --language 2:ger `"(`" `"$($vid_in[$i])`" `")`" --language 0:eng --default-track 0:no `"(`" `"$($sub_eng[$i])`" `")`" --language 0:ger --default-track 0:no `"(`" `"$($sub_ger[$i])`" `")`" --track-order 0:0,0:1,0:2,1:0,2:0" -NoNewWindow -Wait

        Remove-Item -Path $vid_in[$i]
        Start-Sleep -Milliseconds 5
        Rename-Item -Path $vid_out[$i] -NewName $vid_in[$i]
    }

    Pause
#>


<# DEFINITION: Measures time taken to Get-Childitem and to Get-Filehashes (each algorithm separately)

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
#>

<# DEFINITION: trying to figure out RSJob:
    if (-not (Get-Module -ListAvailable -Name PoshRSJob)){
        Write-Host "Module RSJob (https://github.com/proxb/PoshRSJob) is required, but it seemingly isn't installed - please start PowerShell as administrator and run`t" -ForegroundColor Red -NoNewline
        Write-Host "Install-Module -Name PoshRSJob" -ForegroundColor DarkYellow
        Exit
    }

    $timer = [diagnostics.stopwatch]::StartNew()
    $bla_job = @()
    $bla_job += Get-ChildItem -Path "D:\Bilder" -Filter *.jpg -Recurse | ForEach-Object {
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
    $bla_ind += Get-ChildItem -Path "D:\Bilder" -Filter *.jpg -Recurse | ForEach-Object {
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

<# DEFINITION: fooling around with progresses and stuff:
    $i = 1
    $timer = [diagnostics.stopwatch]::StartNew()

    $sw = [diagnostics.stopwatch]::StartNew()
    # $sw.Start()

    $bla = Get-ChildItem -Path D:\Bilder -Recurse -Filter *.jpg | Select-Object -ExpandProperty FullName | ForEach-Object {
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
