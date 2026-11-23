param([string]$FfmpegPath = 'ffmpeg')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceVideo = Join-Path $projectRoot 'assets/images/warnew.mp4'
$outputAudio = Join-Path $projectRoot 'assets/audio/warnew_battle.m4a'
& $FfmpegPath -hide_banner -loglevel error -y -i $sourceVideo -map 0:a:0 -vn -c:a copy $outputAudio
if ($LASTEXITCODE -ne 0) { throw 'Failed to extract the warnew.mp4 audio track.' }
