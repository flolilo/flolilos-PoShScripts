#requires -version 3
param(
    [ValidateScript({($_ % 2) -eq 0})]
    [int]$offset = 0,
    [ValidateRange(5,25)]
    [int]$framerate = 10,
    [ValidateRange(0,1)]
    [int]$gif = 1
)
[string]$date = Get-Date -Format "yy-MM-dd"
[int]$resolution = 1856 + $offset

Start-Sleep -Seconds 3
Write-Host "`a"
Start-Process -FilePath ffmpeg -ArgumentList " -hide_banner -f gdigrab -framerate $framerate -offset_x $offset -offset_y 0 -video_size $($resolution):1200 -i desktop -c:v libx264 -pix_fmt yuv420p -preset ultrafast -crf 16 -intra -an -y F:\screencap_$date.mp4" -NoNewWindow -Wait
Start-Sleep -Seconds 3
if($gif -eq 0){
    Start-Process -FilePath ffmpeg -ArgumentList " -hide_banner -i F:\screencap_$date.mp4 -vf scale=1280:-2 -c:v libx264 -crf 22 -preset veryslow -profile:v high -level 4.2 -an F:\$($date)_webready.mp4" -NoNewWindow -Wait
}else{
    # CREDIT: https://superuser.com/questions/556029/how-do-i-convert-a-video-to-gif-using-ffmpeg-with-reasonable-quality
    Start-Process -FilePath ffmpeg -ArgumentList "-hide_banner -i F:\screencap_$date.mp4 -filter_complex `"scale=1280:-2:flags=lanczos,split[o1][o2];[o1]palettegen[p];[o2]fifo[o3];[o3][p]paletteuse=dither=none`" -b:v 200k -an -y F:\$($date)_webready.gif" -NoNewWindow -Wait
}
Remove-Item -Path F:\screencap_$date.mp4

