import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/old_testament_game.dart';
import 'package:itlective/war_cutscene.dart';

void main() {
  testWidgets(
    'Battle plays once, survives resize and automatically opens Genesis',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.reset);
      final game = OldTestamentGame(playWarVideo: false);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.runAsync(() async {
        for (var i = 0; i < 500; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          if (game.isLoaded && game.war.isMounted) break;
        }
      });
      game.pauseEngine();
      final war = game.war;
      expect(game.router.currentRoute.name, 'war');
      expect(game.playWarVideo, isFalse);
      expect(war.videoControlled, isFalse);
      expect(game.overlays.isActive(OldTestamentGame.warVideoOverlay), isFalse);
      await tester.tapAt(const Offset(200, 200));
      expect(war.isFinished, isFalse); // Only the labelled skip target skips.
      game.update(5);
      expect(war.phase, 'ANGELS AGAINST THE DARKNESS');
      final before = war.elapsed;
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      expect(war.elapsed, before);
      expect(war.skipBounds.right, lessThanOrEqualTo(320));
      game.update(6);
      expect(war.phase, 'THE LIGHT PREVAILS');
      game.update(WarCutscene.duration);
      war.finishCutscene(); // Repeated completion must not stack routes.
      await tester.runAsync(() async {
        for (var i = 0; i < 500; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          game.update(0);
          if (game.router.currentRoute.name == 'intro' &&
              game.router.currentRoute.children.isNotEmpty &&
              game.cutscene.isMounted) {
            break;
          }
        }
      });
      expect(war.elapsed, WarCutscene.duration);
      expect(game.router.currentRoute.name, 'intro');
      expect(game.router.stack, hasLength(1));
      expect(game.cutscene.textIndex, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
