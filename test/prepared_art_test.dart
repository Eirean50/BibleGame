import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/flame.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/keyed_art.dart';

class _PreparedOnlyBundle extends CachingAssetBundle {
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) {
    // Runtime must not download and process the large source sheets again.
    if (!key.startsWith('assets/images/prepared/')) {
      throw StateError('Unexpected source artwork request: $key');
    }
    loads.add(key);
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Eden sheet has clean empty space and opaque pale robes in every pose',
    () async {
      final sprite = await loadKeyedArt('jesuswithadamandeve.png');
      addTearDown(sprite.image.dispose);
      final image = sprite.image;
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final pixels = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      int alpha(int x, int y) => pixels[(y * image.width + x) * 4 + 3];
      // Empty strips above, between and below the six figures previously held
      // many disconnected white flecks from the baked-in checkerboard.
      for (var y = 0; y < image.height; y++) {
        final referenceY = y / image.height * 1143;
        if (referenceY >= 140 && referenceY <= 570 ||
            referenceY >= 634 && referenceY <= 1064) {
          continue;
        }
        for (var x = 0; x < image.width; x++) {
          expect(alpha(x, y), 0, reason: 'Background residue at $x,$y');
        }
      }
      for (final robe in const [
        ui.Offset(504, 460),
        ui.Offset(1190, 460),
        ui.Offset(1844, 460),
        ui.Offset(500, 950),
        ui.Offset(1160, 950),
        ui.Offset(1816, 950),
      ]) {
        expect(
          alpha(
            (robe.dx / 2048 * image.width).floor(),
            (robe.dy / 1143 * image.height).floor(),
          ),
          255,
        );
      }
    },
  );

  test(
    'Play, Level1 and replay share prepared art safely after disposal',
    () async {
      final bundle = _PreparedOnlyBundle();
      final previousCache = Flame.images;
      Flame.images = Images(bundle: bundle);
      addTearDown(() {
        Flame.images.clearCache();
        Flame.images = previousCache;
      });

      for (var visit = 0; visit < 3; visit++) {
        final sprites = await Future.wait(preparedArtNames.map(loadKeyedArt));
        for (final sprite in sprites) {
          expect(sprite.image.width, lessThanOrEqualTo(1024));
          expect(await sprite.image.toByteData(), isNotNull);
          sprite.image.dispose();
        }
      }
      expect(bundle.loads, hasLength(preparedArtNames.length));
    },
  );
}
