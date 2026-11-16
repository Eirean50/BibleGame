import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/era1_screen.dart';

class MissingAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw FlutterError('Missing $key');
}

void main() {
  testWidgets(
    'Cutscene loads, animates, changes dialogue and survives rotation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 432);
      addTearDown(tester.view.reset);
      // A real font makes the optional screenshot readable outside test mode.
      if (const bool.fromEnvironment('CAPTURE_CUTSCENE')) {
        await tester.runAsync(() async {
          final font = File('C:/Windows/Fonts/arial.ttf');
          if (await font.exists()) {
            final loader = FontLoader('Roboto')
              ..addFont(font.readAsBytes().then(ByteData.sublistView));
            await loader.load();
          }
        });
      }
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Era1Screen(),
          ),
        ),
      );
      final game = tester
          .state<GameWidgetState<Era1Game>>(find.byType(GameWidget<Era1Game>))
          .currentGame;
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 500 && !game.isLoaded; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pump();
      game.pauseEngine();
      await tester.pumpAndSettle();
      game.update(0);
      expect(game.isLoaded, isTrue);
      expect(find.text('NAG-UUSAP'), findsOneWidget);
      expect(find.textContaining('Maligayang pagdating'), findsOneWidget);
      expect(game.actors.length, greaterThanOrEqualTo(14));
      expect(tester.takeException(), isNull);

      final oldSeaX = game.sea.x;
      final oldBoatY = game.sailboat.y;
      game.update(1);
      expect(game.sea.x, isNot(oldSeaX));
      expect(game.sailboat.y, isNot(oldBoatY));
      for (final actor in game.actors) {
        expect(
          (actor.y - actor.basePosition.y).abs(),
          lessThanOrEqualTo(actor.verticalAmplitude + 0.001),
        );
      }
      final beforeTap = game.sailboat.position.clone();
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(game.sailboat.position, beforeTap);

      game.update(4.1);
      await tester.pumpAndSettle();
      expect(find.textContaining('Handa kaming magsilbi'), findsOneWidget);

      if (const bool.fromEnvironment('CAPTURE_CUTSCENE')) {
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final preview = await boundary.toImage();
          final bytes = await preview.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await Directory('build').create(recursive: true);
          await File('build/cutscene-preview.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          preview.dispose();
        });
      }

      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        final resized = tester
            .state<GameWidgetState<Era1Game>>(find.byType(GameWidget<Era1Game>))
            .currentGame;
        expect(identical(game, resized), isTrue);
        expect(tester.getSize(find.byType(GameWidget<Era1Game>)), size);
        expect(find.byType(AppBar), findsNothing);
        expect(game.stage.x, lessThanOrEqualTo(0.001));
        expect(game.stage.y, lessThanOrEqualTo(0.001));
        expect(
          game.stage.x + Era1Game.stageWidth * game.stage.scale.x,
          greaterThanOrEqualTo(game.size.x - 0.001),
        );
        expect(
          game.stage.y + Era1Game.stageHeight * game.stage.scale.y,
          closeTo(game.size.y, 0.001),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Missing assets produce an error view instead of an endless loader',
    (tester) async {
      final game = Era1Game(assetBundle: MissingAssets());
      await tester.pumpWidget(
        MaterialApp(
          home: GameWidget(
            game: game,
            errorBuilder: (context, error) =>
                const Text('Could not load scene'),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 10; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Could not load scene'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
