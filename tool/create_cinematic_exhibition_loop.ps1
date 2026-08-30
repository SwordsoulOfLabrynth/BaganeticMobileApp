param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\deliverables\Baganetic_Exhibition_Cinematic_Loop.mp4')
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$renderDirectory = Join-Path $projectRoot 'tmp\cinematic_exhibition_render'
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

$scenes = @(
    [pscustomobject]@{
        Key = '01-intro'; Duration = 5; Screen = 'tmp\emulator_home_ready_qa.png';
        Eyebrow = 'SMART ROUTE & INFO GUIDE'; Title = 'Meet Baganetic.';
        Body = 'A cinematic mobile companion for exploring the ancient wonders of Bagan.';
        Label = 'EXPLORE WITH PURPOSE'
    },
    [pscustomobject]@{
        Key = '02-discover'; Duration = 5; Screen = 'tmp\emulator_home_ready_qa.png';
        Eyebrow = 'DISCOVER'; Title = 'Every pagoda has a story.';
        Body = 'Find places, save favourites, and take the culture of Bagan with you.';
        Label = 'PAGODA DISCOVERY'
    },
    [pscustomobject]@{
        Key = '03-navigate'; Duration = 6; Screen = 'tmp\emulator_map_shortest_qa.png';
        Eyebrow = 'NAVIGATE'; Title = 'Choose the smarter route.';
        Body = 'Explore an interactive map and find the shortest path between landmarks.';
        Label = 'A* ROUTE FINDING'
    },
    [pscustomobject]@{
        Key = '04-plan'; Duration = 6; Screen = 'tmp\trip_detail_final_result.png';
        Eyebrow = 'PLAN'; Title = 'Make every stop count.';
        Body = 'Build multi-stop journeys with a route, useful timing, and place details.';
        Label = 'TRIP PLANNER'
    },
    [pscustomobject]@{
        Key = '05-connect'; Duration = 5; Screen = 'tmp\emulator_community_qa.png';
        Eyebrow = 'CONNECT'; Title = 'Travel with shared knowledge.';
        Body = 'Search local tips and stay connected to the Bagan travel community.';
        Label = 'COMMUNITY FEED'
    },
    [pscustomobject]@{
        Key = '06-cta'; Duration = 7; Screen = 'tmp\emulator_trip_planner_final_qa.png';
        Eyebrow = 'TRY THE APP'; Title = 'Scan. Install. Explore.';
        Body = 'Experience the Baganetic Android exhibition demo today.';
        Label = 'ANDROID DEMO'; QR = 'deliverables\Baganetic-demo-download-qr.png'
    }
)

function Escape-FilterText([string]$Value) {
    return $Value.Replace("'", "\\'").Replace(':', '\\:').Replace(',', '\\,')
}

foreach ($scene in $scenes) {
    $screenPath = Join-Path $projectRoot $scene.Screen
    if (-not (Test-Path -LiteralPath $screenPath)) {
        throw "Missing app screen: $screenPath"
    }

    $frames = $scene.Duration * 30
    $title = Escape-FilterText $scene.Title
    $body = Escape-FilterText $scene.Body
    $eyebrow = Escape-FilterText $scene.Eyebrow
    $label = Escape-FilterText $scene.Label
    $sceneOutput = Join-Path $renderDirectory ("$($scene.Key).mp4")
    $fadeOut = $scene.Duration - 0.45

    $filter = @(
        "[0:v]scale=2200:-2,crop=1920:1080:x='(in_w-out_w)/2+30*sin(t*0.25)':y='(in_h-out_h)/2+18*cos(t*0.25)',format=yuv420p[bg]",
        "[1:v]scale=440:978,zoompan=z='min(zoom+0.00055,1.065)':d=$($frames):s=440x978:fps=30[phone]",
        "[bg]drawbox=x=0:y=0:w=1080:h=1080:color=0x110D0A@0.78:t=fill[copyshade]",
        "[copyshade]drawbox=x=1090:y=36:w=470:h=1005:color=black@0.36:t=fill[phoneshadow]",
        "[phoneshadow][phone]overlay=x='if(lt(t,0.70),1920-(810*t/0.70),1110)':y=51:shortest=1[app]",
        "[app]drawbox=x=1106:y=47:w=448:h=986:color=0xE7C879@0.88:t=3[frame]",
        "[frame]drawbox=x=138:y=146:w=12:h=230:color=0xE7C879:t=fill[accent]",
        "[accent]drawtext=fontfile='$fontBody':text='$eyebrow':fontcolor=0xE7C879:fontsize=24:x=178:y=154[eyebrow]",
        "[eyebrow]drawtext=fontfile='$fontTitle':text='$title':fontcolor=white:fontsize=64:x=178:y=205:line_spacing=12[title]",
        "[title]drawtext=fontfile='$fontBody':text='$body':fontcolor=0xF0E8DE:fontsize=28:x=178:y=410:line_spacing=10[body]",
        "[body]drawbox=x=178:y=838:w=340:h=48:color=0x7A4227@0.92:t=fill[labelbox]",
        "[labelbox]drawtext=fontfile='$fontBody':text='$label':fontcolor=white:fontsize=19:x=200:y=853[label]",
        "[label]drawbox=x=178:y=943:w=470:h=3:color=0xE7C879:t=fill[rule]",
        "[rule]drawtext=fontfile='$fontBody':text='BAGANETIC  /  PROJECT EXHIBITION':fontcolor=0xD4C6B6:fontsize=17:x=178:y=968[premaster]",
        "[premaster]fade=t=in:st=0:d=0.35,fade=t=out:st=$($fadeOut):d=0.45[finished]"
    ) -join ';'

    $inputs = @('-loop', '1', '-i', $cinematicBackground, '-loop', '1', '-i', $screenPath)
    if ($scene.QR) {
        $qrPath = Join-Path $projectRoot $scene.QR
        if (-not (Test-Path -LiteralPath $qrPath)) {
            throw "Missing QR code: $qrPath"
        }
        $inputs += @('-loop', '1', '-i', $qrPath)
        $filter = $filter.Replace('[app]drawbox', "[2:v]scale=190:190[qr];[app][qr]overlay=x=650:y=700:shortest=1[withqr];[withqr]drawbox")
    }

    & $ffmpeg -y @inputs -filter_complex $filter -map '[finished]' -t $scene.Duration -r 30 -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart $sceneOutput
    if ($LASTEXITCODE -ne 0) {
        throw "Could not render cinematic scene $($scene.Key)."
    }
}

$clipList = Join-Path $renderDirectory 'clips.txt'
$scenes | ForEach-Object {
    "file '$((Join-Path $renderDirectory ($_.Key + '.mp4')).Replace('\\', '/'))'"
} | Set-Content -LiteralPath $clipList -Encoding ascii

$combined = Join-Path $renderDirectory 'combined.mp4'
& $ffmpeg -y -f concat -safe 0 -i $clipList -c copy $combined 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Could not combine cinematic video scenes.'
}

$finalPath = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $finalPath) | Out-Null
& $ffmpeg -y -i $combined -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart $finalPath 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'Could not create the final cinematic exhibition video.'
}

Write-Host "Created: $finalPath"
