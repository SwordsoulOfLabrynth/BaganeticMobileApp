param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\deliverables\Baganetic_Continuous_Exhibition_Loop.mp4')
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$renderDirectory = Join-Path $projectRoot 'tmp\exhibition_screen_render'
$fontTitle = 'C\:/Windows/Fonts/georgiab.ttf'
$fontBody = 'C\:/Windows/Fonts/arialbd.ttf'
$cinematicBackground = Join-Path $projectRoot 'output\imagegen\bagan-cinematic-sunrise.png'

if (-not (Test-Path -LiteralPath $cinematicBackground)) {
    throw "Missing cinematic background: $cinematicBackground"
}

if (Test-Path -LiteralPath $renderDirectory) {
    Remove-Item -LiteralPath $renderDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $renderDirectory | Out-Null

# 6 Curated Scenes - 100% Finished Features Only (Zero mock or unfinished screens)
$scenes = @(
    [pscustomobject]@{
        Key = '01-intro'
        Duration = 5.5
        Screen = 'tmp\emulator_home_ready_qa.png'
        Eyebrow = 'SMART CULTURAL GUIDE'
        Title = 'Meet Baganetic.'
        Body1 = 'A cinematic mobile companion for exploring'
        Body2 = 'the ancient pagodas and sacred wonders of Bagan.'
        Badge = 'EXPERIENCE BAGAN'
    },
    [pscustomobject]@{
        Key = '02-catalog'
        Duration = 5.5
        Screen = 'tmp\live_emulator_pagodas.png'
        Eyebrow = 'PAGODA DISCOVERY'
        Title = 'Sacred monuments catalog.'
        Body1 = 'Explore Bagan with verified historical dates,'
        Body2 = 'architectural records, and curated photo journals.'
        Badge = 'HERITAGE ARCHIVES'
    },
    [pscustomobject]@{
        Key = '03-chronicles'
        Duration = 5.5
        Screen = 'tmp\emulator_pagodas_qa.png'
        Eyebrow = 'DEEP CULTURAL INSIGHTS'
        Title = 'Every pagoda has a story.'
        Body1 = 'Explore detailed temple overviews, century-old'
        Body2 = 'origins, and local photography recommendations.'
        Badge = 'TEMPLE DETAILS'
    },
    [pscustomobject]@{
        Key = '04-navigate'
        Duration = 6.0
        Screen = 'tmp\emulator_map_shortest_qa.png'
        Eyebrow = 'SMART NAVIGATION'
        Title = 'Choose the smarter route.'
        Body1 = 'Interactive map with A* shortest pathfinding'
        Body2 = 'between ancient landmarks and sacred sites.'
        Badge = 'A* ROUTE FINDING'
    },
    [pscustomobject]@{
        Key = '05-plan'
        Duration = 6.0
        Screen = 'tmp\trip_detail_final_result.png'
        Eyebrow = 'TRIP PLANNER'
        Title = 'Make every stop count.'
        Body1 = 'Craft multi-stop day journeys with route preview,'
        Body2 = 'precise travel distances, and sunrise viewpoints.'
        Badge = 'MULTI-STOP JOURNEYS'
    },
    [pscustomobject]@{
        Key = '06-cta'
        Duration = 7.0
        Screen = 'tmp\emulator_home_ready_qa.png'
        Eyebrow = 'EXPERIENCE ON YOUR PHONE'
        Title = 'Scan. Install. Explore.'
        Body1 = 'Scan the QR code to install the Android demo'
        Body2 = 'and start discovering ancient Bagan today.'
        Badge = 'ANDROID DEMO LIVE'
        QR = 'deliverables\Baganetic-demo-download-qr.png'
    }
)

function Escape-FilterText([string]$Value) {
    return $Value.Replace("'", "\\'").Replace(':', '\\:').Replace(',', '\\,')
}

Write-Host "Rendering $($scenes.Count) exhibition scenes..."

foreach ($scene in $scenes) {
    $screenPath = Join-Path $projectRoot $scene.Screen
    if (-not (Test-Path -LiteralPath $screenPath)) {
        throw "Missing app screen: $screenPath"
    }

    $frames = [int]($scene.Duration * 30)
    $title = Escape-FilterText $scene.Title
    $body1 = Escape-FilterText $scene.Body1
    $body2 = Escape-FilterText $scene.Body2
    $eyebrow = Escape-FilterText $scene.Eyebrow
    $badge = Escape-FilterText $scene.Badge
    $sceneOutput = Join-Path $renderDirectory ("$($scene.Key).mp4")
    $fadeOut = $scene.Duration - 0.45

    $filterLines = @(
        "[0:v]scale=2200:-2,crop=1920:1080:x='(in_w-out_w)/2+26*sin(t*0.22)':y='(in_h-out_h)/2+14*cos(t*0.22)',format=yuv420p[bg]",
        "[1:v]scale=440:978,zoompan=z='min(zoom+0.00045,1.05)':d=$($frames):s=440x978:fps=30[phone]",
        "[bg]drawbox=x=0:y=0:w=1140:h=1080:color=0x0E0B08@0.84:t=fill[copyshade]",
        "[copyshade]drawbox=x=1220:y=46:w=450:h=990:color=black@0.45:t=fill[phoneshadow]",
        "[phoneshadow][phone]overlay=x=1225:y=51:shortest=1[app]",
        "[app]drawbox=x=1222:y=48:w=446:h=984:color=0xE7C879@0.92:t=3[frame]",
        "[frame]drawbox=x=138:y=160:w=10:h=230:color=0xE7C879:t=fill[accent]",
        "[accent]drawtext=fontfile='$fontBody':text='$eyebrow':fontcolor=0xE7C879:fontsize=22:x=175:y=168[eyebrow]",
        "[eyebrow]drawtext=fontfile='$fontTitle':text='$title':fontcolor=white:fontsize=64:x=175:y=218[title]",
        "[title]drawtext=fontfile='$fontBody':text='$body1':fontcolor=0xF0E8DE:fontsize=28:x=175:y=340[body1]",
        "[body1]drawtext=fontfile='$fontBody':text='$body2':fontcolor=0xF0E8DE:fontsize=28:x=175:y=385[body2]"
    )

    if ($scene.QR) {
        $qrPath = Join-Path $projectRoot $scene.QR
        if (-not (Test-Path -LiteralPath $qrPath)) {
            throw "Missing QR code: $qrPath"
        }
        $inputs = @('-loop', '1', '-i', $cinematicBackground, '-loop', '1', '-i', $screenPath, '-loop', '1', '-i', $qrPath)
        $filterLines += @(
            "[2:v]scale=190:190,pad=206:206:8:8:color=white[qrbox]",
            "[body2][qrbox]overlay=x=175:y=480[withqr]",
            "[withqr]drawtext=fontfile='$fontBody':text='Scan with camera / QR reader':fontcolor=0xE7C879:fontsize=20:x=420:y=530[qrtxt1]",
            "[qrtxt1]drawtext=fontfile='$fontBody':text='Direct APK download for Android':fontcolor=0xD4C6B6:fontsize=18:x=420:y=570[qrtxt2]",
            "[qrtxt2]drawbox=x=175:y=820:w=340:h=46:color=0x7A4227@0.92:t=fill[labelbox]"
        )
    } else {
        $inputs = @('-loop', '1', '-i', $cinematicBackground, '-loop', '1', '-i', $screenPath)
        $filterLines += @(
            "[body2]drawbox=x=175:y=820:w=340:h=46:color=0x7A4227@0.92:t=fill[labelbox]"
        )
    }

    $filterLines += @(
        "[labelbox]drawtext=fontfile='$fontBody':text='$badge':fontcolor=white:fontsize=18:x=195:y=834[label]",
        "[label]drawbox=x=175:y=920:w=480:h=2:color=0xE7C879@0.7:t=fill[rule]",
        "[rule]drawtext=fontfile='$fontBody':text='BAGANETIC  /  CULTURAL HERITAGE & NAVIGATION':fontcolor=0xD4C6B6:fontsize=16:x=175:y=945[premaster]",
        "[premaster]fade=t=in:st=0:d=0.35,fade=t=out:st=$($fadeOut):d=0.45[finished]"
    )

    $filter = $filterLines -join ';'

    & $ffmpeg -hide_banner -loglevel error -y @inputs -filter_complex $filter -map '[finished]' -t $scene.Duration -r 30 -c:v libx264 -preset medium -crf 17 -pix_fmt yuv420p -movflags +faststart $sceneOutput
    if ($LASTEXITCODE -ne 0) {
        throw "Could not render scene $($scene.Key)."
    }
    Write-Host "  Finished scene: $($scene.Key) ($($scene.Duration)s)"
}

# Combine all scenes
$clipList = Join-Path $renderDirectory 'clips.txt'
$scenes | ForEach-Object {
    "file '$((Join-Path $renderDirectory ($_.Key + '.mp4')).Replace('\\', '/'))'"
} | Set-Content -LiteralPath $clipList -Encoding ascii

$combinedVideo = Join-Path $renderDirectory 'combined_raw.mp4'
& $ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $clipList -c copy $combinedVideo
if ($LASTEXITCODE -ne 0) {
    throw 'Could not concatenate exhibition video scenes.'
}

# Calculate total duration
$totalDuration = ($scenes | Measure-Object -Property Duration -Sum).Sum
Write-Host "Total loop duration: $totalDuration seconds"

$finalPath = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $finalPath) | Out-Null

$silentPath = $finalPath.Replace('.mp4', '_Silent.mp4')

# 1. Export Silent continuous loop
Write-Host "Exporting silent continuous loop: $silentPath"
& $ffmpeg -hide_banner -loglevel error -y -i $combinedVideo -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart $silentPath
if ($LASTEXITCODE -ne 0) {
    throw 'Could not create silent exhibition video.'
}

# 2. Export ambient audio continuous loop
Write-Host "Exporting ambient sound continuous loop: $finalPath"
$audioFadeOutStart = $totalDuration - 1.2
& $ffmpeg -hide_banner -loglevel error -y -i $combinedVideo `
    -f lavfi -i "aevalsrc=0.03*sin(2*PI*55*t)+0.015*sin(2*PI*110*t)+0.008*sin(2*PI*220*t)+0.012*sin(2*PI*0.14*t):s=48000:d=$($totalDuration)" `
    -map 0:v:0 -map 1:a:0 -t $totalDuration -c:v copy `
    -c:a aac -b:a 160k -af "lowpass=f=800,afade=t=in:st=0:d=1.0,afade=t=out:st=$($audioFadeOutStart):d=1.2" `
    -movflags +faststart $finalPath
if ($LASTEXITCODE -ne 0) {
    throw 'Could not create audio exhibition video.'
}

Write-Host "Successfully generated:"
Write-Host "1. Primary Exhibition Loop (with soft ambient): $finalPath"
Write-Host "2. Silent Exhibition Loop: $silentPath"
