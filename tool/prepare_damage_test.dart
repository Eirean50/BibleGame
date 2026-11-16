// flutter test tool/prepare_damage_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Prepare supplied damage poses without the checkerboard', () async {
    for (final devil in [false, true]) {
      final sprite = await loadKeyedArt(
        devil ? 'devildamage.png' : 'angel damage.png',
        minimumGray: 40,
        maximumGray: 125,
        tolerance: 12,
        edgeConnectedOnly: true,
        clearEnclosedPatches: false,
        backgroundSeeds: const [ui.Offset(0.48, 0.87), ui.Offset(0.37, 0.50)],
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Coordinates fitted to the supplied 1792x2400 illustrations.
      const referenceWidth = 1361.0;
      const referenceHeight = 1824.0;
      const top = 125.0;
      const bottom = 1685.0;
      const width = 1275.0;
      const scale = 0.5;
      canvas.scale(scale);
      canvas.translate(0, -top);
      if (!devil) {
        // The angel source includes part of another pose above its left wing.
        canvas.clipPath(
          ui.Path()..addPolygon(const [
            ui.Offset(0, 700),
            ui.Offset(270, 310),
            ui.Offset(340, 250),
            ui.Offset(480, 170),
            ui.Offset(580, 150),
            ui.Offset(590, 240),
            ui.Offset(580, 490),
            ui.Offset(700, 500),
            ui.Offset(720, 305),
            ui.Offset(850, 230),
            ui.Offset(1010, 270),
            ui.Offset(1361, 270),
            ui.Offset(1361, 1700),
            ui.Offset(0, 1700),
          ], true),
        );
      }
      canvas.drawImageRect(
        sprite.image,
        ui.Rect.fromLTWH(
          0,
          0,
          sprite.image.width.toDouble(),
          sprite.image.height.toDouble(),
        ),
        const ui.Rect.fromLTWH(0, 0, referenceWidth, referenceHeight),
        ui.Paint()..filterQuality = ui.FilterQuality.none,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (width * scale).ceil(),
        ((bottom - top) * scale).ceil(),
      );
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        'assets/images/prepared/${devil ? 'devil' : 'angel'}damage.png',
      ).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      image.dispose();
      picture.dispose();
      sprite.image.dispose();
    }
  });
}
