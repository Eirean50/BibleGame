// Run explicitly: flutter test tool/prepare_adam_sheep_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Prepare the supplied Adam and sheep animation', () async {
    for (final name in [
      'adampettingsheep.png',
      'sleepingadam.png',
      'adamandeveakbay.png',
    ]) {
      final sprite = await loadKeyedArt(
        name,
        minimumGray: 45,
        maximumGray: 170,
        tolerance: 8,
        edgeConnectedOnly: true,
        cleanSpriteEdges: true,
      );
      final bytes = (await sprite.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      await File('assets/images/prepared/$name').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      sprite.image.dispose();
    }
  });
}
