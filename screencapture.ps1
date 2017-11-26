#requires -version 3
param(
    [ValidateScript({($_ % 2) -eq 0})]
    [int]$offset = 0,
    [ValidateRange(5,25)]
    [int]$framerate = 15
)
[string]$date = Get-Date -Format "yy-MM-dd"
[int]$resolution = 1920 + $offset

Start-Process -FilePath ffmpeg -ArgumentList " -hide_banner -f gdigrab -framerate $framerate -offset_x $offset -offset_y 0 -video_size $($resolution):1200 -i desktop -c:v libx264 -pix_fmt yuv420p -preset ultrafast -crf 14 -intra -an -y F:\screencap_$date.mp4" -NoNewWindow -Wait
Start-Sleep -Seconds 5
Start-Process -FilePath ffmpeg -ArgumentList " -hide_banner -i F:\screencap_$date.mp4 -vf scale=1280:-2 -c:v libx264 -crf 22 -preset veryslow -profile:v high -level 4.2 -an F:\$($date)_webready.mp4" -NoNewWindow -Wait
