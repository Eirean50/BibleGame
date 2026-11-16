// Rebuild after replacing angel_avatar.png:
// flutter test tool/prepare_angel_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Prepare the angel avatar without its baked-in checkerboard', () async {
    final sprite = await loadKeyedArt(
      'angel_avatar.png',
      minimumGray: 40,
      maximumGray: 145,
      tolerance: 12,
      edgeConnectedOnly: true,
      cleanSpriteEdges: true,
    );
    try {
      final bytes = (await sprite.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      await Directory('assets/images/prepared').create(recursive: true);
      await File('assets/images/prepared/angel_avatar.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      sprite.image.dispose();
    }
  });
}
