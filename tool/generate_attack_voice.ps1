# Offline synthesized vocal; run from the project root on Windows.
Add-Type -AssemblyName System.Speech
$speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $speech.SelectVoice('Microsoft David Desktop')
    $speech.Rate = 3
    $speech.Volume = 100
    $speech.SetOutputToWaveFile((Join-Path (Get-Location) 'build/attack_voice_raw.wav'))
    $speech.Speak('Yah!')
} finally {
    $speech.Dispose()
}
