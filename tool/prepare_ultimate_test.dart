// flutter test tool/prepare_ultimate_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Prepare the supplied ultimate sheet at its original crop coordinates',
    () async {
      final sprite = await loadKeyedArt(
        'ultiangels.png',
        minimumGray: 38,
        maximumGray: 165,
        tolerance: 45,
        edgeConnectedOnly: true,
        clearEnclosedPatches: false,
        backgroundSeeds: const [ui.Offset(0.35, 0.95), ui.Offset(0.50, 0.95)],
      );
      // The beam pose sits directly below another fighter's feet. Exclude
      // that fragment while keeping the wide wing tips on either side.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final scaleX = sprite.image.width / 2752;
      final scaleY = sprite.image.height / 1536;
      canvas.clipPath(
        ui.Path.combine(
          ui.PathOperation.difference,
          ui.Path()..addRect(
            ui.Rect.fromLTWH(
              0,
              0,
              sprite.image.width.toDouble(),
              sprite.image.height.toDouble(),
            ),
          ),
          ui.Path()..addRect(
            ui.Rect.fromLTRB(
              1510 * scaleX,
              1020 * scaleY,
              1760 * scaleX,
              1075 * scaleY,
            ),
          ),
        ),
      );
      canvas.drawImage(sprite.image, ui.Offset.zero, ui.Paint());
      final picture = recorder.endRecording();
      final prepared = await picture.toImage(
        sprite.image.width,
        sprite.image.height,
      );
      final bytes = (await prepared.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      await File('assets/images/prepared/ultiangels.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      sprite.image.dispose();
      prepared.dispose();
      picture.dispose();
    },
  );
}
