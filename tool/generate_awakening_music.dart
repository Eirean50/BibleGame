// Original suspense score: quick low pulses, uneasy strings and rising bells.
// No wind, surf, noise beds or downloaded recordings.
import 'dart:math' as math;

import 'generate_genesis_sounds.dart' show rate, writeWave;

void main() {
  final samples = List<double>.filled(rate * 24, 0);
  void note(
    double start,
    double duration,
    int midi,
    double gain, {
    bool pulse = false,
  }) {
    final hz = 440 * math.pow(2, (midi - 69) / 12);
    for (var i = 0; i < (duration * rate).round(); i++) {
      final t = i / rate;
      final phase = 2 * math.pi * hz * t;
      final env = pulse
          ? math.min(1.0, t / 0.012) *
                math.exp(-t * 8) *
                math.min(1.0, (duration - t) / 0.04)
          : math.min(1.0, t / 0.35) * math.min(1.0, (duration - t) / 0.8);
      final vibrato = 0.012 * math.sin(t * 31);
      final tone =
          math.sin(phase + vibrato) +
          0.25 * math.sin(phase * 2) +
          0.12 * math.sin(phase * 3.002);
      samples[((start * rate).round() + i) % samples.length] +=
          gain * env * tone;
    }
  }

  const chords = [
    [38, 45, 53, 64],
    [34, 41, 52, 65],
    [33, 40, 50, 63],
    [37, 44, 55, 62],
  ];
  for (var bar = 0; bar < 4; bar++) {
    final start = bar * 6.0;
    for (final pitch in chords[bar]) {
      note(start, 7.2, pitch, pitch > 60 ? 0.025 : 0.065);
    }
    for (var beat = 0; beat < 12; beat++) {
      note(start + beat * 0.5, 0.45, chords[bar][0], 0.22, pulse: true);
      note(
        start + beat * 0.5 + 0.24,
        0.2,
        chords[bar][0] + 12,
        0.07,
        pulse: true,
      );
      note(
        start + beat * 0.5,
        0.42,
        [74, 77, 75, 81][beat % 4],
        0.04,
        pulse: true,
      );
    }
  }
  final overlap = (rate * 0.3).round();
  for (var i = 0; i < overlap; i++) {
    final blend = i / overlap;
    samples[i] =
        samples[samples.length - overlap + i] * (1 - blend) +
        samples[i] * blend;
  }
  writeWave(
    'genesis_awakening_music',
    samples.sublist(0, samples.length - overlap),
  );
}
