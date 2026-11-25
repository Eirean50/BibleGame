# Generate the offline male vocal, then run dart tool/mix_devil_laugh.dart.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildPath = Join-Path $projectRoot 'build'
New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
Add-Type -AssemblyName System.Speech
$speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $speech.SelectVoice('Microsoft David Desktop')
    $speech.Rate = 1
    $speech.Volume = 100
    $speech.SetOutputToWaveFile((Join-Path $buildPath 'devil_laugh_raw.wav'))
    $speech.Speak('Ha ha ha! Ha ha ha ha!')
} finally {
    $speech.Dispose()
}
