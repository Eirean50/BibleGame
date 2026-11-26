// dart tool/generate_genesis_music.dart
// Original 32-second instrumental: soft pads, plucked arpeggios, and melody.
import 'dart:math' as math;

import 'generate_genesis_sounds.dart' show rate, writeWave;

void main() {
  final samples = List<double>.filled(rate * 32, 0);
  double frequency(int midi) => 440.0 * math.pow(2, (midi - 69) / 12);

  void note(
    double start,
    double duration,
    int midi,
    double gain, {
    bool pad = false,
  }) {
    final offset = (start * rate).round();
    final count = (duration * rate).round();
    final hz = frequency(midi);
    for (var i = 0; i < count; i++) {
      final t = i / rate;
      final phase = 2 * math.pi * hz * t;
      final envelope = pad
          ? math.min(1.0, t / 0.8) * math.min(1.0, (duration - t) / 1.4)
          : math.min(1.0, t / 0.015) *
                math.exp(-t * 1.9) *
                math.min(1.0, (duration - t) / 0.2);
      final tone = pad
          ? math.sin(phase) * 0.75 +
                math.sin(phase * 1.003) * 0.2 +
                math.sin(phase * 2) * 0.05
          : math.sin(phase) +
                0.28 * math.sin(phase * 2) +
                0.10 * math.sin(phase * 3);
      final value = tone * envelope * gain;
      // Wrap sustained notes and echoes across the loop boundary for continuity.
      samples[(offset + i) % samples.length] += value;
      if (!pad) {
        samples[(offset + i + (rate * 0.24).round()) % samples.length] +=
            value * 0.22;
        samples[(offset + i + (rate * 0.48).round()) % samples.length] +=
            value * 0.10;
      }
    }
  }

  const chords = [
    [50, 57, 62, 66], // D
    [47, 54, 59, 62], // B minor
    [43, 55, 59, 62], // G
    [45, 57, 61, 64], // A
    [50, 57, 62, 66],
    [43, 55, 59, 62],
    [45, 57, 62, 64], // A suspended
    [45, 57, 61, 64],
  ];
  const melody = [
    [74, 76, 78, 76],
    [71, 74, 78, 74],
    [67, 71, 74, 76],
    [76, 73, 71, 69],
    [74, 78, 81, 78],
    [79, 78, 76, 74],
    [76, 74, 71, 69],
    [69, 73, 76, 73],
  ];
  const arpeggio = [0, 1, 2, 3, 2, 1, 3, 2];
  for (var bar = 0; bar < chords.length; bar++) {
    final start = bar * 4.0;
    for (final pitch in chords[bar]) {
      note(start, 5.5, pitch, 0.055, pad: true);
    }
    note(start, 4.0, chords[bar].first - 12, 0.04, pad: true);
    for (var beat = 0; beat < arpeggio.length; beat++) {
      note(start + beat * 0.5, 2.2, chords[bar][arpeggio[beat]] + 12, 0.07);
    }
    for (var beat = 0; beat < 4; beat++) {
      note(start + beat, 2.5, melody[bar][beat], 0.055);
    }
  }
  writeWave('genesis_music', samples);
}
