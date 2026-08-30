param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\deliverables\Baganetic_Exhibition_Loop.mp4')
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Source
$renderDirectory = Join-Path $projectRoot 'tmp\exhibition_loop_render'
$fontTitle = 'C\:/Windows/Fonts/georgiab.ttf'
$fontBody = 'C\:/Windows/Fonts/arialbd.ttf'

if (Test-Path -LiteralPath $renderDirectory) {
    Remove-Item -LiteralPath $renderDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $renderDirectory | Out-Null

$scenes = @(
    [pscustomobject]@{
        Key = '01-intro'; Duration = 7; Image = 'tmp\emulator_home_ready_qa.png';
        Eyebrow = 'SMART ROUTE & INFO GUIDE';
        Title = 'Baganetic';
        Body = 'Discover Bagan. Plan every stop. Travel with confidence.';
        Badge = 'MOBILE TOURISM COMPANION'
    },
    [pscustomobject]@{
        Key = '02-discover'; Duration = 7; Image = 'tmp\emulator_home_ready_qa.png';
        Eyebrow = 'DISCOVER';
        Title = 'Bagan, in your pocket.';
        Body = 'Browse pagodas, cultural stories, and favourites in one mobile experience.';
        Badge = 'PAGODA EXPLORATION'
    },
    [pscustomobject]@{
        Key = '03-route'; Duration = 8; Image = 'tmp\emulator_map_shortest_qa.png';
        Eyebrow = 'NAVIGATE';
        Title = 'Find the smarter path.';
        Body = 'Explore the map and calculate shortest paths between Bagan landmarks.';
        Badge = 'A* ROUTE FINDING'
    },
    [pscustomobject]@{
        Key = '04-trip'; Duration = 7; Image = 'tmp\trip_detail_final_result.png';
        Eyebrow = 'PLAN';
        Title = 'Turn stops into a journey.';
        Body = 'Build multi-stop trips, see the route, and move through your day with a plan.';
        Badge = 'TRIP PLANNER'
    },
    [pscustomobject]@{
        Key = '05-community'; Duration = 7; Image = 'tmp\emulator_community_qa.png';
        Eyebrow = 'CONNECT';
        Title = 'Travel with local knowledge.';
        Body = 'Search community tips and share useful information with fellow visitors.';
        Badge = 'COMMUNITY FEED'
    },
    [pscustomobject]@{
        Key = '06-ferry'; Duration = 7; Image = 'tmp\emulator_trip_planner_final_qa.png';
        Eyebrow = 'GO FURTHER';
        Title = 'One map. More ways to move.';
        Body = 'Plan routes across Bagan, including ferry-aware journeys when they are needed.';
        Badge = 'MULTIMODAL ROUTING'
    },
    [pscustomobject]@{
        Key = '07-cta'; Duration = 9; Image = 'tmp\emulator_home_ready_qa.png';
        Eyebrow = 'TRY THE APP';
        Title = 'Start your Bagan journey.';
        Body = 'Scan the QR code to install the exhibition demo on Android.';
        Badge = 'SCAN TO DOWNLOAD'; QR = 'deliverables\Baganetic-demo-download-qr.png'
    }
)

function Escape-FilterText([string]$Value) {
    return $Value.Replace('\\', '\\\\').Replace(':', '\\:').Replace("'", "\\'").Replace(',', '\\,')
}

foreach ($scene in $scenes) {
    $source = Join-Path $projectRoot $scene.Image
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Missing exhibition screenshot: $source"
    }

    $frames = $scene.Duration * 30
    $eyebrow = Escape-FilterText $scene.Eyebrow
    $title = Escape-FilterText $scene.Title
    $body = Escape-FilterText $scene.Body
    $badge = Escape-FilterText $scene.Badge
    $sceneOutput = Join-Path $renderDirectory ("$($scene.Key).mp4")

    # The screen gently zooms during each scene, so the loop feels alive even without sound.
    $filter = @(
        "[0:v]scale=430:956,zoompan=z='min(zoom+0.00028,1.055)':d=$($frames):s=430x956:fps=30[phone]",
        "color=c=0x1d1511:s=1920x1080:d=$($scene.Duration):r=30[base]",
        "[base]drawbox=x=1085:y=48:w=470:h=984:color=black@0.32:t=fill[shadow]",
        "[shadow][phone]overlay=x=1105:y=62:shortest=1[composition]",
        "[composition]drawbox=x=1105:y=62:w=430:h=956:color=0xD9B66C@0.70:t=3[framed]",
        "[framed]drawbox=x=120:y=112:w=16:h=236:color=0xD9B66C:t=fill[accent]",
        "[accent]drawtext=fontfile='$fontBody':text='$eyebrow':fontcolor=0xD9B66C:fontsize=25:x=165:y=120[eyebrow]",
        "[eyebrow]drawtext=fontfile='$fontTitle':text='$title':fontcolor=white:fontsize=68:x=165:y=172:line_spacing=12[title]",
        "[title]drawtext=fontfile='$fontBody':text='$body':fontcolor=0xE4DDD5:fontsize=28:x=165:y=405:line_spacing=14[body]",
        "[body]drawbox=x=165:y=853:w=340:h=52:color=0x5B3925:t=fill[badgebox]",
        "[badgebox]drawtext=fontfile='$fontBody':text='$badge':fontcolor=white:fontsize=20:x=188:y=870[badge]",
        "[badge]drawbox=x=165:y=950:w=470:h=4:color=0xD9B66C:t=fill[rule]",
        "[rule]drawtext=fontfile='$fontBody':text='PROJECT EXHIBITION  |  BAGANETIC':fontcolor=0xBEB2A8:fontsize=18:x=165:y=978[finished]"
    ) -join ';'

    $inputs = @('-loop', '1', '-i', $source)
    if ($scene.QR) {
        $qr = Join-Path $projectRoot $scene.QR
        if (-not (Test-Path -LiteralPath $qr)) {
            throw "Missing QR code: $qr"
        }
        $inputs += @('-loop', '1', '-i', $qr)
        $filter = $filter.Replace('[composition]drawbox', "[1:v]scale=200:200[qr];[composition][qr]overlay=x=780:y=760:shortest=1[withqr];[withqr]drawbox")
    }

    & $ffmpeg -y @inputs -filter_complex $filter -map '[finished]' -t $scene.Duration -r 30 -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -movflags +faststart $sceneOutput
    if ($LASTEXITCODE -ne 0) {
        throw "Could not render scene $($scene.Key)."
    }
}

$clipList = Join-Path $renderDirectory 'clips.txt'
$scenes | ForEach-Object {
    "file '$((Join-Path $renderDirectory ($_.Key + '.mp4')).Replace('\\', '/'))'"
} | Set-Content -LiteralPath $clipList -Encoding ascii

$temporaryCombined = Join-Path $renderDirectory 'combined.mp4'
& $ffmpeg -y -f concat -safe 0 -i $clipList -c copy $temporaryCombined
if ($LASTEXITCODE -ne 0) {
    throw 'Could not combine exhibition video scenes.'
}

$finalPath = [System.IO.Path]::GetFullPath($OutputPath)
$finalDirectory = Split-Path -Parent $finalPath
New-Item -ItemType Directory -Force -Path $finalDirectory | Out-Null
& $ffmpeg -y -i $temporaryCombined -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart $finalPath
if ($LASTEXITCODE -ne 0) {
    throw 'Could not create the final exhibition video.'
}

Write-Host "Created: $finalPath"
