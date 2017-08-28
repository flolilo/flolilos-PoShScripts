#================================================================================
#================================================================================
# Come to set the global values? Take a look here...
param([string]$encoder = "C:\FFMPEG\binaries\ffmpeg.exe")

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
        Title="Flos Ü-Kamera-Split v1.2" Height="390" Width="550">
    <Grid Background="#FFB3B6B5">
        <TextBlock x:Name="textBlockWelcome" HorizontalAlignment="Center" Margin="11,20,11,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="33" Width="520" FontSize="18" TextAlignment="Center" Text="Willkommen bei Flos Überwachungskamera-Splitter v1.2!"/>
        <TextBlock x:Name="textBlockInput" HorizontalAlignment="Left" Margin="19,72,0,0" TextWrapping="Wrap" Text="Pfad 4screen:" VerticalAlignment="Top" Height="18" Width="78"/>
        <TextBlock x:Name="textBlock1" HorizontalAlignment="Left" Margin="143,189,0,0" TextWrapping="Wrap" Text="Die Quelle ist eine ..." VerticalAlignment="Top"/>
        <TextBlock x:Name="textBlock2" HorizontalAlignment="Left" Margin="106,236,0,0" TextWrapping="Wrap" Text="Falls Quadscreen die Quelle ist:" VerticalAlignment="Top"/>
        <TextBlock x:Name="textBlockVon" HorizontalAlignment="Left" Margin="185,117,0,0" TextWrapping="Wrap" Text="Von: (hh mm ss)" VerticalAlignment="Top"/>
        <TextBlock x:Name="textBlockBis" HorizontalAlignment="Left" Margin="191,147,0,0" TextWrapping="Wrap" Text="Bis: (hh mm ss)" VerticalAlignment="Top"/>
        <TextBox x:Name="textBoxInput" HorizontalAlignment="Left" Height="23" Margin="103,71,0,0" Text="X:\2017-01-01_quad.mkv" VerticalAlignment="Top" Width="318" ToolTip="Pfad zur Datei, aus der ein Teil herausgerechnet werden soll." UndoLimit="10" VerticalScrollBarVisibility="Disabled"/>
        <TextBox x:Name="textBoxFromH" HorizontalAlignment="Left" Height="23" Margin="278,113,0,0" TextWrapping="Wrap" Text="00" VerticalAlignment="Top" Width="30" ToolTip="Stunden" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" MaxLength="2"/>
        <TextBox x:Name="textBoxFromM" HorizontalAlignment="Left" Height="23" Margin="313,113,0,0" TextWrapping="Wrap" Text="00" VerticalAlignment="Top" Width="30" ToolTip="Minuten" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" MaxLength="2"/>
        <TextBox x:Name="textBoxFromS" HorizontalAlignment="Left" Height="23" Margin="348,113,0,0" TextWrapping="Wrap" Text="00" VerticalAlignment="Top" Width="30" ToolTip="Sekunden" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" MaxLength="2"/>
        <TextBox x:Name="textBoxToH" HorizontalAlignment="Left" Height="23" Margin="278,146,0,0" TextWrapping="Wrap" Text="00" VerticalAlignment="Top" Width="30" ToolTip="Stunden" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" MaxLength="2"/>
        <TextBox x:Name="textBoxToM" HorizontalAlignment="Left" Height="23" Margin="313,146,0,0" TextWrapping="Wrap" Text="00" VerticalAlignment="Top" Width="30" ToolTip="Minuten" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" MaxLength="2"/>
        <TextBox x:Name="textBoxToS" HorizontalAlignment="Left" Height="23" Margin="348,146,0,0" TextWrapping="Wrap" Text="00" VerticalAlignment="Top" Width="30" ToolTip="Sekunden" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" MaxLength="2"/>
        <Button x:Name="buttonSearchIn" Content="Durchsuchen..." HorizontalAlignment="Right" Margin="0,70,20,0" VerticalAlignment="Top" Width="90" Height="24"/>
        <Button x:Name="buttonStart" Content="START" HorizontalAlignment="Center" Margin="216,323,216,0" VerticalAlignment="Top" Width="110" HorizontalContentAlignment="Center"/>
        <Button x:Name="buttonClose" Content="Ende" HorizontalAlignment="Right" Margin="0,323,20,0" VerticalAlignment="Top" Width="60"/>
        <CheckBox x:Name="checkBoxCamA" Content="Cam 1" HorizontalAlignment="Left" Margin="284,222,0,0" VerticalAlignment="Top" ToolTip="Kamera 1 herausrechnen" Width="60" Padding="4,-1,0,0"/>
        <CheckBox x:Name="checkBoxCamB" Content="Cam 2" HorizontalAlignment="Left" Margin="360,222,0,0" VerticalAlignment="Top" Padding="4,-1,0,0" ToolTip="Kamera 2 herausrechnen" Width="60"/>
        <CheckBox x:Name="checkBoxCamC" Content="Cam 3" HorizontalAlignment="Left" Margin="284,255,0,0" VerticalAlignment="Top" ToolTip="Kamera 3 herausrechnen" Width="60" Padding="4,-1,0,0"/>
        <CheckBox x:Name="checkBoxCamD" Content="Cam 4" HorizontalAlignment="Left" Margin="360,255,0,0" VerticalAlignment="Top" Width="60" ToolTip="Kamera 4 herausrechnen"/>
        <CheckBox x:Name="checkBoxHardware" Content="Hardware-Rendering" HorizontalAlignment="Left" Margin="203,292,0,0" VerticalAlignment="Top" IsChecked="True" ToolTip="Beschleunigt Ausgabe, Ergebnis bitte testen. Empfehlung: AN bei Monika, AUS bei Franz."/>
        <ComboBox x:Name="comboBoxDatei" HorizontalAlignment="Left" Margin="263,186,0,0" VerticalAlignment="Top" Width="150" SelectedIndex="0">
            <ComboBoxItem Content="Quadscreen-Datei"/>
            <ComboBoxItem Content="Originale Kamera-Datei"/>
        </ComboBox>
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
    $Form.Close()
    Exit
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

#                     $encoder             $userCam         $userFileFull       $userFileName       $userFilePath       $userFrom         $userTo         $userfiletype     $userhardware
Function Flo-Splitter($FloSplitterEncoder, $FloSplitterCam, $FloSplitterInFull, $FloSplitterInName, $FloSplitterInPath, $FloSplitterFrom, $FloSplitterTo, $FloSplitterMeth, $FloSplitterHardware){
    $separator = "_"
    $option = [System.StringSplitOptions]::RemoveEmptyEntries
    $neuname = $FloSplitterInName.Split($separator,$option)
    $arguments_A = " -i `"$FloSplitterInFull`" -ss $($FloSplitterFrom[0]):$($FloSplitterFrom[1]):$($FloSplitterFrom[2]).00 -to $($FloSplitterTo[0]):$($FloSplitterTo[1]):$($FloSplitterTo[2]).00 -hide_banner -an -map_metadata -1"
    $encodeparam = " -c:v libx264 -preset veryslow -crf 18", " -c:v h264_qsv -preset veryslow -q 18 -look_ahead 0"
    if($FloSplitterMeth -eq 0){
        $splitparam = " -filter:v `"crop=in_w/2:in_h/2:0:0`"", " -filter:v `"crop=in_w/2:in_h/2:in_w/2:0`"", " -filter:v `"crop=in_w/2:in_h/2:0:in_h/2`"", " -filter:v `"crop=in_w/2:in_h/2:in_w/2:in_h/2`""
        for($i=0; $i -lt 4; $i++){
            if($FloSplitterCam[$i] -eq $true){
                $neuname[1] = "cam$($i + 1)"
                $arguments_Z = " `"$FloSplitterInPath\$($neuname[1])_$($neuname[0])_split_$($FloSplitterFrom[0])-$($FloSplitterFrom[1])-$($FloSplitterFrom[2])_$($FloSplitterTo[0])-$($FloSplitterTo[1])-$($FloSplitterTo[2]).mkv`"" 
                if($FloSplitterHardware -eq 1){
                    Start-Process -FilePath $FloSplitterEncoder -ArgumentList $arguments_A, $encodeparam[$FloSplitterHardware], $splitparam[$i], $arguments_z -Wait
                    Start-Sleep -Milliseconds 100
                    Write-Host "Cam $($i +1) kodiert." -ForegroundColor Yellow
                }Else{
                    Start-Process -FilePath $FloSplitterEncoder -ArgumentList $arguments_A, $encodeparam[$FloSplitterHardware], $splitparam[$i], $arguments_z
                    Write-Host "Cam $($i +1) kodiert." -ForegroundColor Yellow
                }
            }
        }
    }Else{
        $arguments_Z = " `"$FloSplitterInPath\$($FloSplitterInName)_split_$($FloSplitterFrom[0])-$($FloSplitterFrom[1])-$($FloSplitterFrom[2])_$($FloSplitterTo[0])-$($FloSplitterTo[1])-$($FloSplitterTo[2]).mkv`"" 
        Start-Process -FilePath $FloSplitterEncoder -ArgumentList $arguments_A, $encodeparam[$FloSplitterHardware], $arguments_z
        Write-Host "Cam kodiert." -ForegroundColor Yellow
    }
    while($prozesse -ne 0){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 250
    }
    Write-Host " "
    Write-Host "Fertig!" -ForegroundColor Green
    Write-Host " "
}


#===========================================================================
#===========================================================================
# Programming the buttons:
#===========================================================================

$WPFbuttonStart.Add_Click({
    Start-Process powershell -ArgumentList "$PSScriptRoot\preventsleep.ps1 -mode 1 -zeitbasis 100" -WindowStyle Minimized
    $userfiletype = $WPFcomboBoxDatei.SelectedIndex
    if($WPFcheckBoxHardware.IsChecked -eq $true){
        $userhardware = 1
    }Else{
        $userhardware = 0
    }
    $userCam = "0","0","0","0"
    $userInput = Get-ChildItem $WPFtextBoxInput.Text
    $userFileFull = $userInput.FullName
    $userFileName = $userInput.BaseName
    $userFilePath = $userInput.Directory
    $userCam[0] = $WPFcheckBoxCamA.IsChecked
    $userCam[1] = $WPFcheckBoxCamB.IsChecked
    $userCam[2] = $WPFcheckBoxCamC.IsChecked
    $userCam[3] = $WPFcheckBoxCamD.IsChecked
    $userFrom = "0","0","0"
    $userFrom[0] = $WPFtextBoxFromH.Text
    $userFrom[1] = $WPFtextBoxFromM.Text
    $userFrom[2] = $WPFtextBoxFromS.Text
    $userTo = "0","0","0"
    $userTo[0] = $WPFtextBoxToH.Text
    $userTo[1] = $WPFtextBoxToM.Text
    $userTo[2] = $WPFtextBoxToS.Text
    $Form.WindowState = 'Minimized'
    Flo-Splitter $encoder $userCam $userFileFull $userFileName $userFilePath $userFrom $userTo $userfiletype $userhardware
    $Form.WindowState = 'Normal'
})

$WPFbuttonSearchIn.Add_Click({
    $searchIn = Get-Folder -InitialDirectory $deski
    $WPFtextBoxInput.Text = $searchIn
})

$WPFbuttonClose.Add_Click({
    $Form.Close()
    Exit
})


#================================================================================
#================================================================================
# Show/Start the GUI: 
#================================================================================

Write-Host "Hallo bei Flos Überwachungskamera-Split-Skript v1.2!" -ForegroundColor Cyan
Write-Host " "
$Form.ShowDialog() | out-null
