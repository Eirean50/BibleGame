// Run generate_devil_laugh.ps1 first. Deepens the male vocal and adds echoes.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'mix_attack_sound.dart' show readWave;

void main() {
  const rate = 44100;
  final (sourceRate, source) = readWave('build/devil_laugh_raw.wav');
  final first = source.indexWhere((sample) => sample.abs() > 0.008);
  final last = source.lastIndexWhere((sample) => sample.abs() > 0.008);
  if (first < 0) throw StateError('The laugh source is silent.');
  final voice = source.sublist(
    math.max(0, first - sourceRate ~/ 100),
    math.min(source.length, last + sourceRate ~/ 25),
  );
  final peak = voice.map((sample) => sample.abs()).reduce(math.max);
  final step = sourceRate / rate * 0.72;
  final voiceLength = ((voice.length - 1) / step).floor();
  final samples = List<double>.filled(voiceLength + (rate * 0.9).round(), 0);
  for (var i = 0; i < voiceLength; i++) {
    final position = i * step;
    final low = position.floor();
    final value = voice[low] + (voice[low + 1] - voice[low]) * (position - low);
    final fade = math.min(
      1.0,
      math.min(i, voiceLength - 1 - i) / (rate * 0.015),
    );
    final dry = math.atan(value / peak * 1.5) * 0.75 * fade;
    samples[i] += dry;
    for (var echo = 1; echo <= 3; echo++) {
      samples[i + (rate * 0.22 * echo).round()] += dry * math.pow(0.36, echo);
    }
  }
  final mixedPeak = samples.map((sample) => sample.abs()).reduce(math.max);
  final gain = 0.90 / mixedPeak;
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
  File('assets/audio/devil_laugh.wav')
      .writeAsBytesSync(wav.buffer.asUint8List());
  stdout.writeln(
    'Devil laugh: ${(samples.length / rate).toStringAsFixed(2)}s, 44100 Hz PCM.',
  );
}
