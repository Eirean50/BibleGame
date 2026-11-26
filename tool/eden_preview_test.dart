// Optional visual review: flutter test tool/eden_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/eden_cutscene.dart';

import '../test/flutter_test_config.dart' as test_config;

Future<void> main() => test_config.testExecutable(() async {
  testWidgets('Capture Eden close-up, retreat and reveal', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final font = File('C:/Windows/Fonts/consola.ttf');
      if (await font.exists()) {
        await (FontLoader(
          'monospace',
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
    });
    final scene = EdenCutscene(onFinished: () {});
    final game = FlameGame(children: [scene]);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: GameWidget(game: game),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (scene.isMounted) break;
      }
    });
    game.pauseEngine();
    for (var step = 0; step < 3; step++) {
      if (step > 0) {
        game.update(6);
        scene.advance();
      }
      if (scene.isTyping) scene.advance();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      game.resumeEngine();
      await tester.pump(const Duration(milliseconds: 1));
      game.pauseEngine();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build').create(recursive: true);
        await File('build/eden-$step.png').writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  });
});
