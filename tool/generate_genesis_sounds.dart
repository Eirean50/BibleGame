// dart tool/generate_genesis_sounds.dart
// Original synthesized effects. No recordings or downloaded samples.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 44100;

void main() {
  for (final kind in ['waters', 'wind', 'nature']) {
    final random = math.Random(71 + kind.length);
    final duration = kind == 'nature' ? 10 : 8;
    var low = 0.0;
    var soft = 0.0;
    final samples = List<double>.generate(rate * duration, (i) {
      final t = i / rate;
      final noise = random.nextDouble() * 2 - 1;
      low += (noise - low) * 0.025;
      soft += (noise - soft) * 0.16;
      final swell = 0.5 + 0.5 * math.sin(2 * math.pi * t / 4);
      if (kind == 'waters') {
        return low * 0.7 + soft * (0.14 + 0.28 * swell);
      }
      return low * (0.65 + 0.35 * swell) + soft * 0.05;
    });
    if (kind == 'nature') {
      // Short rising and falling chirps, with irregular gaps between calls.
      for (final start in [0.7, 1.0, 2.6, 4.3, 4.6, 6.8, 7.1, 8.5]) {
        final offset = (start * rate).round();
        final length = (rate * 0.18).round();
        var phase = 0.0;
        for (var i = 0; i < length; i++) {
          final p = i / length;
          phase += 2 * math.pi * (1700 + 1100 * math.sin(math.pi * p)) / rate;
          final envelope = math.pow(math.sin(math.pi * p), 2);
          samples[offset + i] +=
              (math.sin(phase) + 0.15 * math.sin(phase * 2)) * envelope * 0.22;
        }
      }
    }
    // Join each loop with a short overlap so the seam cannot click.
    final overlap = (rate * 0.18).round();
    for (var i = 0; i < overlap; i++) {
      final blend = i / overlap;
      samples[i] =
          samples[samples.length - overlap + i] * (1 - blend) +
          samples[i] * blend;
    }
    writeWave('genesis_$kind', samples.sublist(0, samples.length - overlap));
  }

  final reveal = List<double>.filled((rate * 2.6).round(), 0);
  final notes = [220.0, 329.63, 440.0, 554.37, 659.25, 880.0];
  for (var note = 0; note < notes.length; note++) {
    final onset = note * 0.10;
    for (var i = (onset * rate).round(); i < reveal.length; i++) {
      final t = i / rate - onset;
      final envelope = math.min(1.0, t / 0.035) * math.exp(-t * 2.1);
      final tail = math.min(1.0, (reveal.length - 1 - i) / (rate * 0.15));
      reveal[i] +=
          (math.sin(2 * math.pi * notes[note] * t) +
              0.16 * math.sin(2 * math.pi * notes[note] * 2.01 * t)) *
          envelope *
          tail *
          0.12;
    }
  }
  writeWave('genesis_reveal', reveal);
}

void writeWave(String name, List<double> samples) {
  final bytes = ByteData(44 + samples.length * 2);
  void label(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  label(0, 'RIFF');
  bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
  label(8, 'WAVE');
  label(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  label(36, 'data');
  bytes.setUint32(40, samples.length * 2, Endian.little);
  final peak = samples.map((s) => s.abs()).reduce(math.max);
  final gain = peak > 0.9 ? 0.9 / peak : 1.0;
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(
      44 + i * 2,
      (samples[i] * gain * 32767).round(),
      Endian.little,
    );
  }
  File('assets/audio/$name.wav').writeAsBytesSync(bytes.buffer.asUint8List());
  stdout.writeln('$name: ${(samples.length / rate).toStringAsFixed(2)}s');
}
