#================================================================================
#================================================================================
# Come to set the global values? Take a look here...

# Path to ffmpeg.exe (e.g. "C:\Path\ffmpeg.exe")
$encoder = "C:\FFMPEG\binaries\ffmpeg.exe"

# Set the the standard-path for file dialogues
$deski = "MyComputer"
#================================================================================


#================================================================================
#================================================================================
# Setting up the GUI:
#================================================================================

$inputXML = @"
<Window x:Class="FlosFFmpegSkripte.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:FlosFFmpegSkripte"
        mc:Ignorable="d"
        Title="Flos FFmpeg-Compare v1.0" Height="250" Width="705">
    <Grid Background="#FFB3B6B5">
        <TextBlock x:Name="textBlockWelcome" HorizontalAlignment="Center" Margin="0,20,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="52" Width="521" FontSize="18" TextAlignment="Center"><Run Text="Welcome to Flo's Video-Comparison-Script v1.0"/><LineBreak/><Run Text="Powered by FFmpeg"/></TextBlock>
        <TextBlock x:Name="textBlockInA" HorizontalAlignment="Left" Margin="15,86,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="18" Width="80" Text="Path Video 1:"/>
        <TextBlock x:Name="textBlockInB" HorizontalAlignment="Left" Margin="15,118,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="18" Width="80" Text="Path Video 2:"/>
        <TextBlock x:Name="textBlockOut" HorizontalAlignment="Left" Margin="15,148,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="18" Width="80" Text="Output-Path:"/>
        <Button x:Name="buttonStart" Content="START" HorizontalAlignment="Left" Margin="190,182,0,0" VerticalAlignment="Top" Width="110"/>
        <Button x:Name="buttonClose" Content="Exit" HorizontalAlignment="Left" Margin="472,182,0,0" VerticalAlignment="Top" Width="60"/>
        <Button x:Name="buttonSearchInA" Content="Find..." HorizontalAlignment="Left" Margin="577,85,0,0" VerticalAlignment="Top" Width="90" Height="24"/>
        <Button x:Name="buttonSearchInB" Content="Find..." HorizontalAlignment="Left" Margin="577,115,0,0" VerticalAlignment="Top" Width="90" Height="24"/>
        <Button x:Name="buttonSearchOut" Content="Find..." HorizontalAlignment="Left" Margin="577,145,0,0" VerticalAlignment="Top" Width="90" Height="24"/>
        <TextBox x:Name="textBoxInA" HorizontalAlignment="Left" Height="23" Margin="111,85,0,0" Text="D:\video_original.mkv" VerticalAlignment="Top" Width="450" VerticalScrollBarVisibility="Disabled"/>
        <TextBox x:Name="textBoxInB" HorizontalAlignment="Left" Height="23" Margin="111,115,0,0" Text="D:\video_new.mkv" VerticalAlignment="Top" Width="450" VerticalScrollBarVisibility="Disabled"/>
        <TextBox x:Name="textBoxOut" HorizontalAlignment="Left" Height="23" Margin="111,145,0,0" Text="D:\video_compare.mkv" VerticalAlignment="Top" Width="450" VerticalScrollBarVisibility="Disabled"/>
    </Grid>
</Window>
"@
 
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:Name",'Name'  -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
catch{Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."}
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}

Function Get-FormVariables{
    if ($global:ReadmeDisplay -ne $true){
        Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;
        $global:ReadmeDisplay=$true
    }
    write-host "Found the following interactable elements:" -ForegroundColor Cyan
    get-variable WPF*
}

# If you want to see the variables the GUI has to offer, set this to 1:
$programmierung = 0
if($programmierung -ne 0){
    Get-FormVariables
}


#================================================================================
#================================================================================
# Actually make the objects work:
#================================================================================

# Programming the functions for file-dialogue, copying and verifying:
Function Get-Folder($initialDirectory){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
    $foldername = New-Object System.Windows.Forms.OpenFileDialog
    $foldername.InitialDirectory = $initialDirectory
    $foldername.ShowDialog() | Out-Null
    return $foldername.FileName
}
Function Set-Folder($initialDirectory){
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
    $foldername = New-Object System.Windows.Forms.SaveFileDialog
    $foldername.InitialDirectory = $initialDirectory
    $foldername.ShowDialog() | Out-Null
    return $foldername.FileName
}


#===========================================================================
#===========================================================================
# Programming the buttons:
#===========================================================================

$WPFbuttonStart.Add_Click({
    Clear-Host
    Start-Process powershell -ArgumentList "$PSScriptRoot\preventsleep.ps1 -mode 1 -zeitbasis 100" -WindowStyle Minimized
    $userInputA = $WPFtextBoxInA.Text
    $userInputB = $WPFtextBoxInB.Text
    $userOutput = $WPFtextBoxOut.Text
    $arguments = " -i `"$userInputA`" -i `"$userInputB`" -hide_banner -filter_complex `"[1:v]format=yuva444p,lut=c3=128,negate[video2withAlpha],[0:v][video2withAlpha]overlay[out]`" -map `"[out]`" -c:v libx264 -pix_fmt yuv444p -preset veryslow -intra -crf 10 -an -map_metadata -1 `"$userOutput`""
    Write-Host "FFmpeg Arguments: $arguments" -ForegroundColor Yellow
    Write-Host " "
    $Form.WindowState = 'Minimized'
    Start-Process -FilePath $encoder -ArgumentList $arguments -Wait -NoNewWindow
    $Form.WindowState = 'Normal'
})

$WPFbuttonSearchInA.Add_Click({
    $searchIn = Get-Folder -InitialDirectory $deski
    $WPFtextBoxInA.Text = $searchIn
})

$WPFbuttonSearchInB.Add_Click({
    $searchOut = Get-Folder -InitialDirectory $deski
    $WPFtextBoxInB.Text = $searchOut
})

$WPFbuttonSearchOut.Add_Click({
    $searchOut = Set-Folder -InitialDirectory $deski
    $WPFtextBoxOut.Text = $searchOut
})

$WPFbuttonClose.Add_Click({
    $Form.Close()
    Exit
})


#================================================================================
#================================================================================
# Show/Start the GUI: 
#================================================================================

$Form.ShowDialog() | out-null
