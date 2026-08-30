param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\deliverables\Baganetic_Live_App_Demo.mp4')
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$rawCapture = Join-Path $projectRoot 'tmp\baganetic_live_demo_raw.mp4'
$cinematicBackground = Join-Path $projectRoot 'output\imagegen\bagan-cinematic-sunrise.png'
$finalPath = [System.IO.Path]::GetFullPath($OutputPath)

if (-not (Test-Path -LiteralPath $rawCapture)) { throw "Missing live emulator capture: $rawCapture" }
if (-not (Test-Path -LiteralPath $cinematicBackground)) { throw "Missing cinematic background: $cinematicBackground" }

# A genuine touch-driven recording: no slides, captions, mock phone frame, or QR card.
# The Bagan backdrop receives a slow camera move while the app footage remains at native aspect ratio.
$filter = @(
    "[0:v]trim=duration=22,setpts=PTS-STARTPTS,fps=30,scale=474:1053:force_original_aspect_ratio=decrease[app]",
    "[1:v]scale=2200:-2,crop=1920:1080:x='(in_w-out_w)/2+24*sin(t*0.22)':y='(in_h-out_h)/2+14*cos(t*0.22)',format=yuv420p[bg]",
    "[bg]drawbox=x=0:y=0:w=1920:h=1080:color=0x070504@0.18:t=fill[toned]",
    "[toned]drawbox=x=696:y=0:w=528:h=1080:color=black@0.34:t=fill[shadow]",
    "[shadow][app]overlay=x=723:y=14:shortest=1[composed]",
    "[composed]fade=t=in:st=0:d=0.35,fade=t=out:st=21.55:d=0.45[finished]"
) -join ';'

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $finalPath) | Out-Null
& $ffmpeg -y -i $rawCapture -loop 1 -i $cinematicBackground -filter_complex $filter -map '[finished]' -t 22 -r 30 -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart $finalPath
if ($LASTEXITCODE -ne 0) { throw 'Could not create live app demonstration video.' }

Write-Host "Created: $finalPath"
