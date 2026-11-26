import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/serpent_encounter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('All six Eve poses retain opaque hair, skin and clothing', () async {
    final data = await rootBundle.load(
      'assets/images/prepared/evewalk-solid.png',
    );
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    final solidRecorder = ui.PictureRecorder();
    ui.Canvas(solidRecorder)
        .drawImage(image, ui.Offset.zero, SerpentEncounter.evePaint);
    final solidPicture = solidRecorder.endRecording();
    final solid = await solidPicture.toImage(image.width, image.height);
    final pixels = (await solid.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    const centers = [280, 750, 1180, 1620, 2070, 2498];
    for (final center in centers) {
      for (final point in [
        ui.Offset(center.toDouble(), 210),
        ui.Offset(center.toDouble(), 265),
        ui.Offset(center.toDouble(), 420),
        ui.Offset(center.toDouble(), 515),
      ]) {
        final x = (point.dx / 2752 * image.width).round();
        final y = (point.dy / 1536 * image.height).round();
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            expect(
              pixels.getUint8(((y + dy) * image.width + x + dx) * 4 + 3),
              255,
              reason: 'Opaque character at $point',
            );
          }
        }
      }
    }
    expect(pixels.getUint8(3), 0); // Transparent outside the character only.
    if (const bool.fromEnvironment('GENESIS_PREVIEW')) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF00C5CF), ui.BlendMode.src);
      for (var i = 0; i < centers.length; i++) {
        final source = ui.Rect.fromLTWH(
          (centers[i] - 190) / 2752 * image.width,
          140 / 1536 * image.height,
          380 / 2752 * image.width,
          630 / 1536 * image.height,
        );
        canvas.drawImageRect(
          image,
          source,
          ui.Rect.fromLTWH(i * 220.0, 0, 220, 365),
          SerpentEncounter.evePaint,
        );
      }
      final picture = recorder.endRecording();
      final preview = await picture.toImage(1320, 365);
      final bytes = (await preview.toByteData(format: ui.ImageByteFormat.png))!;
      await File('build/eve-opaque-poses.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      preview.dispose();
      picture.dispose();
    }
    image.dispose();
    solid.dispose();
    solidPicture.dispose();
  });
}
