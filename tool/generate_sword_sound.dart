// dart run tool/generate_sword_sound.dart
// Original synthesized sword swish; no downloaded or licensed samples.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const rate = 44100;
  const duration = 0.36;
  final count = (rate * duration).round();
  final wav = ByteData(44 + count * 2);
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
  wav.setUint32(40, count * 2, Endian.little);
  final random = math.Random(27);
  var filtered = 0.0;
  var previousNoise = 0.0;
  var phase = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / rate;
    final p = t / duration;
    final noise = random.nextDouble() * 2 - 1;
    filtered += (noise - filtered) * (0.18 + 0.48 * math.sin(math.pi * p));
    final envelope = math.pow(math.sin(math.pi * p), 1.5);
    phase += 2 * math.pi * (1100 - 780 * p) / rate;
    final swish = (filtered * 0.8 + (noise - previousNoise) * 0.16) * envelope;
    final ringTime = math.max(0.0, t - 0.09);
    final ring = t < 0.09
        ? 0.0
        : math.sin(2 * math.pi * 2350 * ringTime) *
              math.exp(-ringTime * 26) *
              math.min(1.0, ringTime / 0.008) *
              0.12;
    final sample = (swish + math.sin(phase) * envelope * 0.05 + ring) * 0.85;
    wav.setInt16(
      44 + i * 2,
      (sample.clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
    previousNoise = noise;
  }
  Directory('assets/audio').createSync(recursive: true);
  File('assets/audio/sword_slash.wav')
      .writeAsBytesSync(wav.buffer.asUint8List());
}
