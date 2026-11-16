// Optional visual review: flutter test tool/menu_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/main.dart';

void main() {
  for (final size in [const Size(1440, 900), const Size(390, 844)]) {
    testWidgets('Menu preview at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        for (final entry in {
          'serif': 'timesbd.ttf',
          'Roboto': 'segoeui.ttf',
          'monospace': 'consola.ttf',
        }.entries) {
          final file = File('C:/Windows/Fonts/${entry.value}');
          if (await file.exists()) {
            await (FontLoader(
              entry.key,
            )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
          }
        }
      });
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: const OldTestamentApp()),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/God-background.png'),
          tester.element(find.byType(Scaffold)),
        );
        await Flame.images.ready();
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build').create(recursive: true);
        await File('build/menu-${size.width.toInt()}.png').writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
