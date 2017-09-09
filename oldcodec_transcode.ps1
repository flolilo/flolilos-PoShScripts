[array]$file = "v a -- c:v:0 h264 - c:a:0 dts stereo" # 1
$file += "vidfile1.ext"
$file += "v a -- c:v:0 h264 - c:a:0 dts 5.1" # 2
$file += "vidfile2.ext"
$file += "vidfile3.ext"

$encoder = "cmd.exe"
$argumentA = " /k ffmpeg -hide_banner"
$separator = "."
$option = [System.StringSplitOptions]::RemoveEmptyEntries
[int]$j=0


for($i = 0; $i -lt $file.Length; $i++){
    $folder = [System.IO.Path]::GetDirectoryName($file[$i])
    Set-Location $folder
    $dateinamenteile = $file[$i].Split($separator,$option)
    $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
    $modus = $file[$i]
    while($prozesse -ge 8){
        $prozesse = @(Get-Process -ErrorAction SilentlyContinue -Name ffmpeg).count
        Start-Sleep -Milliseconds 100
    }
    if($modus -like "v a*"){
        j++
    }Else{
        if($j -eq 1){
            # "v a -- c:v:0 h264 - c:a:0 dts stereo" # 1
            Start-Process -FilePath $encoder -ArgumentList "$ArgumentA -i $($file[$i]) -c:v copy -c:a libopus -b:a 128k -cutoff 20000 -n $($dateinamenteile[0])_OPUS.mkv"
        }
        if($j -eq 2){
            # "v a -- c:v:0 h264 - c:a:0 dts 5.1" # 2
            Start-Process -FilePath $encoder -ArgumentList "$ArgumentA -i $($file[$i]) -c:v copy -af `"channelmap=channel_layout=5.1`" -c:a libopus -b:a 384k -cutoff 20000 -n $($dateinamenteile[0])_OPUS.mkv"
        }
    }
}
