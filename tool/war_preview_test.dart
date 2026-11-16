// Optional visual review: flutter test tool/war_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/war_cutscene.dart';

void main() {
  testWidgets('Capture the battle in landscape and portrait', (tester) async {
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
    final scene = WarCutscene(onFinished: () {});
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
      for (var i = 0; i < 500; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (scene.isMounted) break;
      }
    });
    game.pauseEngine();
    for (var step = 0; step < 4; step++) {
      if (step < 3) game.update([3.8, 6.6, 2.6][step]);
      if (step == 3) tester.view.physicalSize = const Size(320, 568);
      game.resumeEngine();
      await tester.pump(const Duration(milliseconds: 1));
      game.pauseEngine();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build').create(recursive: true);
        await File('build/war-$step.png').writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
