// dart tool/generate_serpent_music.dart
// Original restrained suspense: low minor strings, pulses and distant bells.
import 'dart:math' as math;

import 'generate_genesis_sounds.dart' show rate, writeWave;

void main() {
  final samples = List<double>.filled(rate * 32, 0);
  void note(
    double start,
    double duration,
    int midi,
    double gain, {
    bool bell = false,
  }) {
    final hz = 440 * math.pow(2, (midi - 69) / 12);
    for (var i = 0; i < (duration * rate).round(); i++) {
      final t = i / rate;
      final phase = 2 * math.pi * hz * t;
      final envelope = bell
          ? math.min(1.0, t / 0.04) *
                math.exp(-t * 1.3) *
                math.min(1.0, (duration - t) / 0.3)
          : math.min(1.0, t / 1.2) * math.min(1.0, (duration - t) / 1.8);
      final tone = bell
          ? math.sin(phase) + 0.22 * math.sin(phase * 2.01)
          : math.sin(phase) +
                0.20 * math.sin(phase * 1.002) +
                0.12 * math.sin(phase * 3);
      final value = gain * envelope * tone;
      final index = (start * rate).round() + i;
      samples[index % samples.length] += value;
      if (bell) {
        samples[(index + (rate * 0.43).round()) % samples.length] +=
            value * 0.25;
      }
    }
  }

  const chords = [
    [38, 45, 53],
    [38, 46, 52],
    [34, 41, 50],
    [33, 40, 46],
  ];
  for (var bar = 0; bar < 4; bar++) {
    final start = bar * 8.0;
    for (final midi in chords[bar]) {
      note(start, 10, midi, 0.075);
    }
    for (var beat = 0; beat < 4; beat++) {
      note(start + beat * 2, 2.4, chords[bar][0] + 12, 0.055, bell: true);
    }
    note(start + 1.5, 5, [74, 75, 77, 73][bar], 0.04, bell: true);
    note(start + 5, 4, [69, 70, 74, 70][bar], 0.03, bell: true);
  }
  // Blend the tail into the head, then trim the overlap for a click-free loop.
  final overlap = (rate * 0.3).round();
  for (var i = 0; i < overlap; i++) {
    final blend = i / overlap;
    samples[i] =
        samples[samples.length - overlap + i] * (1 - blend) +
        samples[i] * blend;
  }
  writeWave(
    'genesis_serpent_music',
    samples.sublist(0, samples.length - overlap),
  );
}
