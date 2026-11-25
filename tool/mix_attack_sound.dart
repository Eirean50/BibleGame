// Run generate_attack_voice.ps1 first, then dart tool/mix_attack_sound.dart.
// Combines the offline synthesized "Yah!" with our original sword swish.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

(int, List<double>) readWave(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var rate = 0;
  var channels = 0;
  for (var offset = 12; offset + 8 <= bytes.length;) {
    final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final length = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (tag == 'fmt ') {
      if (data.getUint16(start, Endian.little) != 1 ||
          data.getUint16(start + 14, Endian.little) != 16) {
        throw StateError('Expected 16-bit PCM: $path');
      }
      channels = data.getUint16(start + 2, Endian.little);
      rate = data.getUint32(start + 4, Endian.little);
    } else if (tag == 'data' && rate > 0) {
      return (
        rate,
        [
          for (var i = start; i < start + length; i += channels * 2)
            data.getInt16(i, Endian.little) / 32768,
        ],
      );
    }
    offset = start + length + (length % 2);
  }
  throw StateError('Missing WAV data: $path');
}

void main() {
  const rate = 44100;
  final (voiceRate, rawVoice) = readWave('build/attack_voice_raw.wav');
  final (_, swish) = readWave('assets/audio/sword_slash.wav');
  final start = math.max(
    0,
    rawVoice.indexWhere((x) => x.abs() > 0.008) - voiceRate ~/ 100,
  );
  final end = math.min(
    rawVoice.length,
    rawVoice.lastIndexWhere((x) => x.abs() > 0.008) + voiceRate ~/ 50,
  );
  final voice = rawVoice.sublist(start, end);
  final peak = voice.map((x) => x.abs()).reduce(math.max);
  // Lower the male voice by about five semitones for a deeper battle cry.
  // Resample only the voice so the sword swish keeps its original character.
  const voiceSpeed = 0.76;
  final voiceStep = voiceRate / rate * voiceSpeed;
  final voiceLength = math.min(
    (voice.length / voiceStep).floor(),
    (rate * 0.40).round(),
  );
  final samples = List<double>.filled(math.max(voiceLength, swish.length), 0);
  for (var i = 0; i < voiceLength; i++) {
    // Keep pitch fixed even if a longer source reaches the swing-length limit.
    final position = i * voiceStep;
    final low = position.floor();
    final high = math.min(low + 1, voice.length - 1);
    final value = voice[low] + (voice[high] - voice[low]) * (position - low);
    final fade = math.min(
      1.0,
      math.min(i, voiceLength - 1 - i) / (rate * 0.006),
    );
    samples[i] += value / peak * 0.83 * fade;
  }
  for (var i = 0; i < swish.length; i++) {
    samples[i] += swish[i] * 0.65;
  }
  final mixedPeak = samples.map((x) => x.abs()).reduce(math.max);
  final gain = math.min(1.0, 0.94 / mixedPeak);
  final wav = ByteData(44 + samples.length * 2);
  void label(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      wav.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  label(0, 'RIFF');
  wav.setUint32(4, wav.lengthInBytes - 8, Endian.little);
  label(8, 'WAVE');
  label(12, 'fmt ');
  wav.setUint32(16, 16, Endian.little);
  wav.setUint16(20, 1, Endian.little);
  wav.setUint16(22, 1, Endian.little);
  wav.setUint32(24, rate, Endian.little);
  wav.setUint32(28, rate * 2, Endian.little);
  wav.setUint16(32, 2, Endian.little);
  wav.setUint16(34, 16, Endian.little);
  label(36, 'data');
  wav.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    wav.setInt16(
      44 + i * 2,
      (samples[i] * gain * 32767).round(),
      Endian.little,
    );
  }
  File('assets/audio/sword_attack.wav')
      .writeAsBytesSync(wav.buffer.asUint8List());
  stdout.writeln(
    'Attack clip: ${(samples.length / rate).toStringAsFixed(3)} seconds, 44100 Hz PCM.',
  );
}
