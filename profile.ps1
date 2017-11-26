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
        Version:        0.1.0 (Beta)
        Author:         flolilo
        Creation Date:  2017-11-26
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
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
        [string]$InputFile,
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
        [string]$OutputPath,
        <#
            [Parameter(Mandatory=$false)]
            [ValidateSet("none","yyyy-MM-dd","yyyy-MM-dd_HH-mm-ss","yyyy-MM-dd","yyyy-MM-dd_HH-mm-ss","yyyy_MM_dd","yyyy_MM_dd-HH_mm_ss","yy_MM_dd","yy_MM_dd-HH_mm_ss")]
            [string]$NameStyle = "none",
        #>
        [Parameter(Mandatory=$false)]
        [ValidateRange(0,1)]
        [int]$Overwrite = 0
    )

    if($Overwrite -eq 0){
        if((Test-Path -LiteralPath "$OutputPath$(Split-Path -Path $InputFile -Leaf)" -PathType Leaf) -eq $true){
            if((Read-Host "`"$OutputPath$(Split-Path -Path $InputFile -Leaf)`" already present - overwrite?") -ne 1){
                return
            }
        }
    }

    $hashIn = (Get-FileHash -LiteralPath $InputFile -Algorithm SHA1 | Select-Object -ExpandProperty Hash)

    [string]$RC_OutputPath = $(
        if($OutputPath.Substring($OutputPath.Length-1) -eq "\"){
            "`"$($OutputPath.Substring(0,$OutputPath.Length-1))`""
        }else{
            "`"$OutputPath`""
        }
    )
    [string]$RC_InputPath = "`"$(Split-Path -Path $InputFile -Parent)`""
    [string]$RC_InputName = "`"$(Split-Path -Path $InputFile -Leaf)`""
    [string]$ArgList = "$RC_InputPath $RC_OutputPath $RC_InputName /R:5 /W:15 /NJH /NJS /NC /J"

    while($true){
        Start-Process robocopy -ArgumentList $ArgList -Wait -NoNewWindow
        Start-Sleep -Seconds 1
        $hashOut = (Get-FileHash -LiteralPath "$OutputPath$(Split-Path -Path $InputFile -Leaf)" -Algorithm SHA1 | Select-Object -ExpandProperty Hash)
        if(@(Compare-Object -ReferenceObject $hashIn -DifferenceObject $hashOut).Count -gt 0){
            [System.Console]::WriteLine("Input-Hash $hashIn != Output-Hash $hashOut")
            Start-Sleep -Seconds 1
            continue
        }else{
            [System.Console]::WriteLine("Done!")
            break
        }
    }
}
