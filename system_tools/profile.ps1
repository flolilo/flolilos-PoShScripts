# CREDIT: https://superuser.com/a/1259916/703240
# DEFINITION: https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#span-idtextformattingspanspan-idtextformattingspanspan-idtextformattingspantext-formatting
Function Prompt(){
    $ESC = [char]27
    "$ESC[4;38;2;228;87;0m$($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1))$ESC[0m "
}

Function Start-SingleCopy(){
    <#
        .SYNOPSIS
            Copy and verify a single file.
        .DESCRIPTION
            Using Robocopy and Get-FileHash to copy a file.
        .NOTES
            Version:        0.1.2
            Author:         flolilo
            Creation Date:  2018-05-22
            Legal stuff: This program is free software. It comes without any warranty, to the extent permitted by
            applicable law.

        .PARAMETER InputFile
            File to copy.
        .PARAMETER OutputPath
            Path where the file should be copied to.
        .PARAMETER Overwrite
            If enabled (1), automatically overwrite existing files.

        .EXAMPLE
            Start-SingleCopy "D:\My Files\test.txt" D:\
    #>
    param(
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
        [string]$InputFile = $(throw '-InputFile is needed by Start-SingleCopy to work!'),
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
        [string]$OutputPath = $(throw '-OutputPath is needed by Start-SingleCopy to work!'),
        [ValidateRange(0,1)]
        [int]$Overwrite = 0
    )
    $InputFile = Resolve-Path -LiteralPath $InputFile
    $OutputPath = Resolve-Path -LiteralPath $OutputPath

    if($Overwrite -eq 0){
        if((Test-Path -LiteralPath "$OutputPath\$(Split-Path -Path $InputFile -Leaf)" -PathType Leaf) -eq $true){
            [int]$inter = 0
            [int]$inter = Read-Host "`"$OutputPath\$(Split-Path -Path $InputFile -Leaf)`" already present - overwrite?"
            if($inter -ne 1){
                [System.Console]::WriteLine("Aborting!")
                return
            }
        }
    }

    [string]$hashIn = (Get-FileHash -LiteralPath $InputFile -Algorithm SHA1).Hash # | Select-Object -ExpandProperty Hash)

    [string]$RC_OutputPath = $OutputPath
    [string]$RC_InputPath = $(Split-Path -Path $InputFile -Parent)
    [string]$RC_InputName = $(Split-Path -Path $InputFile -Leaf)
    [string]$ArgList = "`"$RC_InputPath`" `"$RC_OutputPath`" `"$RC_InputName`" /R:3 /W:5 /NJH /NJS /NC /J"

    while($true){
        Start-Process robocopy -ArgumentList $ArgList -Wait -NoNewWindow
        Start-Sleep -Milliseconds 250
        [string]$hashOut = (Get-FileHash -LiteralPath "$OutputPath\$(Split-Path -Path $InputFile -Leaf)" -Algorithm SHA1 | Select-Object -ExpandProperty Hash)
        if(@(Compare-Object -ReferenceObject $hashIn -DifferenceObject $hashOut).Count -gt 0){
            [System.Console]::WriteLine("Retry:`t$hashIn != $hashOut")
            Start-Sleep -Milliseconds 750
            continue
        }else{
            [System.Console]::WriteLine("Done!`t$hashIn = $hashOut")
            break
        }
    }
}
