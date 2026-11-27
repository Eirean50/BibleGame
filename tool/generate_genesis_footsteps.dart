// Six quiet, dry footsteps for Jesus's entrance. No continuous ambience.
import 'dart:math' as math;

import 'generate_genesis_sounds.dart' show rate, writeWave;

void main() {
  final samples = List<double>.filled((rate * 3.2).round(), 0);
  final random = math.Random(38);
  for (var step = 0; step < 6; step++) {
    final offset = (rate * (0.12 + step * 0.5)).round();
    var low = 0.0;
    for (var i = 0; i < (rate * 0.2).round(); i++) {
      final t = i / rate;
      low += ((random.nextDouble() * 2 - 1) - low) * 0.10;
      final envelope =
          math.min(1.0, t / 0.008) *
          math.exp(-t * 32) *
          math.min(1.0, (0.2 - t) / 0.04);
      samples[offset + i] +=
          envelope * (0.38 * math.sin(2 * math.pi * 95 * t) + 0.6 * low);
    }
  }
  writeWave('genesis_footsteps', samples);
}
