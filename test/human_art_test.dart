import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/human_character.dart';
import 'package:itlective/keyed_art.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Human artwork clears outer and enclosed checkerboard; light fades out',
    () async {
      final sheet = await loadKeyedArt('human.png');
      addTearDown(sheet.image.dispose);
      final bytes = (await sheet.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alphaAt(double x, double y) {
        final px = (x / 2048 * sheet.image.width).floor();
        final py = (y / 1143 * sheet.image.height).floor();
        return bytes.getUint8((py * sheet.image.width + px) * 4 + 3);
      }

      expect(alphaAt(20, 20), 0);
      expect(
        alphaAt(988, 480),
        lessThan(10),
      ); // Background inside the bent arm.
      expect(alphaAt(1160, 720), 255); // Preserve the character's skin.

      final human = HumanCreation(image: sheet.image, position: Vector2.zero())
        ..opacity = 1;
      expect(human.lightIntensity, 0);
      human.update(0.6);
      expect(human.lightIntensity, 1);
      human.update(7.4);
      expect(human.isFormed, isTrue);
      expect(human.lightIntensity, 1);
      human.update(2);
      expect(human.lightIntensity, 0);
      final levelHuman = HumanCreation(
        image: sheet.image,
        position: Vector2.zero(),
        alreadyFormed: true,
      );
      expect(levelHuman.lightIntensity, 0);

      if (const bool.fromEnvironment('CAPTURE_CREATION')) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final preview = HumanCreation(
          image: sheet.image,
          position: Vector2.zero(),
        )..opacity = 1;
        const times = [0.5, 1.3, 2.9, 4.5, 6.1, 10.0];
        var previous = 0.0;
        for (var i = 0; i < times.length; i++) {
          preview.update(times[i] - previous);
          previous = times[i];
          canvas.save();
          canvas.translate((i % 3) * 320.0, (i ~/ 3) * 540.0);
          canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 320, 540));
          canvas.drawRect(
            const ui.Rect.fromLTWH(0, 0, 320, 540),
            ui.Paint()..color = const ui.Color(0xFF273B50),
          );
          canvas.drawRect(
            const ui.Rect.fromLTWH(0, 470, 320, 70),
            ui.Paint()..color = const ui.Color(0xFF36503A),
          );
          canvas.translate(160, 500);
          canvas.scale(3);
          preview.render(canvas);
          canvas.restore();
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(960, 1080);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build').create(recursive: true);
        await File('build/human-creation-preview.png').writeAsBytes(
          png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        );
        image.dispose();
        picture.dispose();
      }
    },
  );
}
