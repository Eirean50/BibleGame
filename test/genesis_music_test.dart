import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/genesis_music.dart';
import 'package:itlective/sword_sound.dart';

class _Sound extends SwordSound {
  int plays = 0;
  int stops = 0;
  int disposals = 0;
  double gain = 1;
  @override
  Future<void> setGain(double value) async => gain = value;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Serpent music fades in once and survives pause and final route', () {
    final peaceful = _Sound();
    final serpent = _Sound();
    final music = GenesisMusic(sound: peaceful, serpentSound: serpent);
    music.start();
    expect(serpent.plays, 0);
    music.useSerpentTheme();
    music.useSerpentTheme();
    expect(serpent.plays, 1);
    expect(serpent.gain, 0);
    music.update(1.25);
    expect(peaceful.gain, closeTo(0.5, 0.001));
    expect(serpent.gain, closeTo(0.5, 0.001));
    music.pause();
    music.update(10);
    expect(serpent.gain, closeTo(0.5, 0.001));
    music.resume();
    music.update(1.25);
    expect(peaceful.gain, 0);
    expect(peaceful.stops, 2);
    expect(serpent.gain, 1);
    music.start(); // The final field route retains the selected music.
    expect(serpent.plays, 2);
    music.pause();
    music.resume();
    expect(peaceful.plays, 2);
    expect(serpent.plays, 3);
    music.dispose();
    music.dispose();
    expect(peaceful.disposals, 1);
    expect(serpent.disposals, 1);
    music.start();
    music.useSerpentTheme();
    expect(serpent.plays, 3);
  });

  test(
    'Music stays silent before Genesis and does not restart between scenes',
    () {
      final sound = _Sound();
      final music = GenesisMusic(sound: sound);
      music.resume();
      expect(sound.plays, 0);
      music.start();
      music.start();
      music.start();
      expect(sound.plays, 1);
      music.pause();
      expect(sound.stops, 1);
      // A route finishing loading in the background stays silent.
      music.start();
      expect(sound.plays, 1);
      music.resume();
      music.resume();
      expect(sound.plays, 2);
      music.dispose();
      music.dispose();
      music.start();
      music.resume();
      expect(sound.disposals, 1);
      expect(sound.plays, 2);
    },
  );

  for (final track in {
    GenesisMusic.asset: 32.0,
    GenesisMusic.serpentAsset: 31.7,
  }.entries) {
    test('${track.key} is audible without clipping or a seam click', () async {
      final data = await rootBundle.load('assets/${track.key}');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      final rate = data.getUint32(24, Endian.little);
      expect(rate, 44100);
      expect(data.getUint32(40, Endian.little), data.lengthInBytes - 44);
      final count = (data.lengthInBytes - 44) ~/ 2;
      expect(count / rate, track.value);
      var peak = 0;
      var energy = 0.0;
      for (var i = 44; i < data.lengthInBytes; i += 2) {
        final sample = data.getInt16(i, Endian.little);
        if (sample.abs() > peak) peak = sample.abs();
        energy += (sample / 32768) * (sample / 32768);
      }
      expect(peak, inExclusiveRange(1000, 32767));
      expect(energy / count, greaterThan(0.0001));
      final first = data.getInt16(44, Endian.little);
      final last = data.getInt16(data.lengthInBytes - 2, Endian.little);
      expect((first - last).abs(), lessThan(1000));
    });
  }
}
