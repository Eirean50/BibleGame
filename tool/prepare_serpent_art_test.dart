// flutter test tool/prepare_serpent_art_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'art_keyer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Prepare Eve, the tree and the serpent for the field scene', () async {
    for (final name in ['evewalk.png', 'snake.png', 'tree.png']) {
      final tree = name == 'tree.png';
      final sprite = await loadKeyedArt(
        name,
        minimumGray: tree ? 16 : 30,
        maximumGray: tree ? 100 : 170,
        tolerance: tree ? 5 : 8,
        backgroundColors: tree
            ? List.generate(
                47,
                (i) => ui.Color.fromARGB(
                  255,
                  23 + i,
                  23 + (50 * i / 46).round(),
                  34 + (50 * i / 46).round(),
                ),
              )
            : const [],
        edgeConnectedOnly: true,
        cleanSpriteEdges: true,
        cleanNeutralEdges: name == 'evewalk.png',
        maximumWidth: name == 'evewalk.png' ? 2752 : 1024,
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
