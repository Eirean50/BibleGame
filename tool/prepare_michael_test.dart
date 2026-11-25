// Rebuild with: flutter test tool/prepare_michael_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Prepare Michael using the existing sprite pipeline', () async {
    final sprite = await loadKeyedArt(
      'Michael.jpg',
      minimumGray: 28,
      maximumGray: 115,
      tolerance: 12,
      edgeConnectedOnly: true,
      clearEnclosedPatches: false,
      cleanSpriteEdges: true,
    );
    try {
      final bytes = (await sprite.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      await File('assets/images/prepared/michael.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      sprite.image.dispose();
    }
  });
}
