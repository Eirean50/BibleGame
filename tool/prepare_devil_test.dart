// Rebuild after replacing devil.png: flutter test tool/prepare_devil_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Prepare the devil while preserving its dark armor and wings', () async {
    final sprite = await loadKeyedArt(
      'devil.png',
      minimumGray: 40,
      maximumGray: 145,
      tolerance: 10,
      edgeConnectedOnly: true,
      clearEnclosedPatches: false,
      cleanSpriteEdges: true,
    );
    try {
      final bytes = (await sprite.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      await Directory('assets/images/prepared').create(recursive: true);
      await File('assets/images/prepared/devil.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      sprite.image.dispose();
    }
  });
}
