param(
  [string]$Output = "deliverables\Baganetic_Commercial_Cut.mp4"
)

$ErrorActionPreference = 'Stop'

$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$root = Join-Path $PSScriptRoot '..'
$pikaPath = 'C:\Users\Kyaw Zay Ya Hein\Downloads\Video\Pika_4.mp4'
$pikaAerial = 'C:\Users\Kyaw Zay Ya Hein\Downloads\Video\Pika_3.mp4'
$sunrise = Join-Path $root 'output\imagegen\bagan-cinematic-sunrise.png'
$appDemo = Join-Path $root 'tmp\baganetic_live_demo_raw.mp4'
$icon = Join-Path $root 'assets\images\baganetic_launcher_icon.png'
$outPath = Join-Path $root $Output
$opening = Join-Path $root 'tmp\commercial-opening.mp4'
$appSection = Join-Path $root 'tmp\commercial-app-section.mp4'
$endSection = Join-Path $root 'tmp\commercial-end.mp4'
$concatFile = Join-Path $root 'tmp\commercial-concat.txt'

New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

# 1. Clean Pika movement for the opening.
& $ffmpeg -hide_banner -loglevel error -y -i $pikaPath -i $pikaAerial `
  -filter_complex "[0:v]fps=30,scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,trim=duration=5,setpts=PTS-STARTPTS[p0];[1:v]fps=30,scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,trim=duration=5,setpts=PTS-STARTPTS[p1];[p0][p1]xfade=transition=fade:duration=0.35:offset=4.65[v]" `
  -map '[v]' -t 9.65 -an -c:v libx264 -crf 17 -pix_fmt yuv420p $opening

# 2. The real app capture in a handset over a subtle moving Bagan backdrop.
& $ffmpeg -hide_banner -loglevel error -y -loop 1 -i $sunrise -i $appDemo `
  -filter_complex "[0:v]scale=2300:-2,zoompan=z='min(zoom+0.0007,1.11)':x='iw/2-(iw/zoom/2)+70*sin(on/45)':y='ih/2-(ih/zoom/2)':d=360:s=1920x1080:fps=30,drawbox=x=0:y=0:w=iw:h=ih:color=0x06111C@0.18:t=fill[bg];[1:v]fps=30,trim=start=0:end=12,setpts=PTS-STARTPTS,scale=400:889:flags=lanczos,pad=440:940:20:20:color=0x07131F,drawbox=x=0:y=0:w=440:h=940:color=0xEBD6AA@0.32:t=3,drawbox=x=188:y=7:w=64:h=7:color=0x07131F:t=fill,drawbox=x=156:y=920:w=128:h=4:color=0xEBD6AA@0.55:t=fill[phone];[bg][phone]overlay=x='740+14*sin(2*PI*t/7)':y='70+5*sin(2*PI*t/5)':shortest=1[v]" `
  -map '[v]' -t 12 -an -c:v libx264 -crf 17 -pix_fmt yuv420p $appSection

# 3. Short brand close, with no presentation-style feature cards.
& $ffmpeg -hide_banner -loglevel error -y -loop 1 -i $sunrise -loop 1 -i $icon `
  -filter_complex "[0:v]scale=1920:1080,drawbox=x=0:y=0:w=iw:h=ih:color=0x06111C@0.38:t=fill[bg];[1:v]scale=76:76,format=rgba[appIcon];[bg][appIcon]overlay=x=922:y=300,drawtext=fontfile='C\:/Windows/Fonts/arialbd.ttf':text='BAGANETIC':fontcolor=0xF7EBC8:fontsize=54:x=(w-text_w)/2:y=400,drawtext=fontfile='C\:/Windows/Fonts/arial.ttf':text='YOUR JOURNEY THROUGH BAGAN':fontcolor=0xF7EBC8:fontsize=18:x=(w-text_w)/2:y=470[v]" `
  -map '[v]' -t 2.35 -an -c:v libx264 -crf 17 -pix_fmt yuv420p $endSection

@(
  "file '$opening'"
  "file '$appSection'"
  "file '$endSection'"
) | Set-Content -LiteralPath $concatFile -Encoding ascii

& $ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $concatFile `
  -f lavfi -i "aevalsrc=0.035*sin(2*PI*55*t)+0.018*sin(2*PI*110*t)+0.012*sin(2*PI*220*t)+0.024*sin(2*PI*0.14*t):s=48000:d=24" `
  -map 0:v:0 -map 1:a:0 -t 24 -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p `
  -c:a aac -b:a 160k -af "lowpass=f=900,afade=t=in:st=0:d=1.2,afade=t=out:st=22.4:d=1.4" -movflags +faststart $outPath

Remove-Item -LiteralPath $opening,$appSection,$endSection,$concatFile -Force -ErrorAction SilentlyContinue
Write-Host "Created $outPath"
