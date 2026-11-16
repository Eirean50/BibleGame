// Run explicitly after replacing source artwork:
// flutter test tool/prepare_art_test.dart
// Kept outside test/ so ordinary test runs never modify bundled assets.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Prepare transparent, game-sized artwork once before shipping',
    () async {
      final output = Directory('assets/images/prepared');
      await output.create(recursive: true);
      for (final name in [
        'Ground.png',
        'Bird.png',
        'Deer.png',
        'lion.png',
        'human.png',
        'jesuswithadamandeve.png',
        'warangels.png',
      ]) {
        final darkBackground = name == 'Bird.png' || name == 'Deer.png';
        final enclosed =
            name == 'lion.png' ||
            name == 'human.png' ||
            name == 'jesuswithadamandeve.png' ||
            name == 'warangels.png';
        final sprite = await loadKeyedArt(
          name,
          minimumGray: name == 'warangels.png'
              ? 100
              : darkBackground
              ? 28
              : name == 'lion.png'
              ? 175
              : name == 'human.png'
              ? 170
              : 135,
          maximumGray: name == 'warangels.png'
              ? 205
              : darkBackground
              ? 125
              : 255,
          tolerance: name == 'warangels.png'
              ? 10
              : name == 'jesuswithadamandeve.png'
              ? 4
              : name == 'Ground.png'
              ? 24
              : name == 'lion.png'
              ? 20
              : 18,
          edgeConnectedOnly: enclosed,
          clearEnclosedPatches:
              name != 'jesuswithadamandeve.png' && name != 'warangels.png',
          cleanSpriteEdges:
              name == 'jesuswithadamandeve.png' || name == 'warangels.png',
          backgroundSeeds: name == 'jesuswithadamandeve.png'
              ? const [
                  ui.Offset(0.065, 0.306),
                  ui.Offset(0.383, 0.306),
                  ui.Offset(0.706, 0.306),
                  ui.Offset(0.065, 0.735),
                  ui.Offset(0.386, 0.735),
                  ui.Offset(0.710, 0.735),
                ]
              : const [],
        );
        try {
          final bytes = (await sprite.image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('${output.path}/$name').writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        } finally {
          sprite.image.dispose();
        }
      }
      // The dove sheet uses a mid-gray checkerboard, unlike the other sprites.
      final spirit = await loadKeyedArt(
        'holyspirit.png',
        minimumGray: 70,
        maximumGray: 200,
        tolerance: 12,
        edgeConnectedOnly: true,
        keyWarmGlow: true,
      );
      try {
        final bytes = (await spirit.image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        await File('${output.path}/holyspirit.png').writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        spirit.image.dispose();
      }
    },
  );
}
