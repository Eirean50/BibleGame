import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/old_testament_game.dart';

Future<void> enterKingdom(WidgetTester tester, OldTestamentGame game) async {
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      if (game.isLoaded && game.war.isMounted) break;
    }
  });
  game.pauseEngine();
  expect(game.router.currentRoute.name, 'war');
  expect(game.war.isFinished, isFalse);
  expect(game.war.elapsed, lessThan(3));
  // Use the real skip hit target to enter gameplay before Genesis.
  await tester.tapAt(game.war.skipBounds.center);
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 500; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      game.update(0);
      if (game.router.currentRoute.name == 'Level1' &&
          game.router.currentRoute.children.isNotEmpty &&
          game.kingdom.isMounted) {
        break;
      }
    }
  });
  expect(game.router.currentRoute.name, 'Level1');
  expect(game.kingdom.isMounted, isTrue);
}

Future<void> enterGenesis(WidgetTester tester, OldTestamentGame game) async {
  await enterKingdom(tester, game);
  // Only the explicit continue button leaves the kingdom.
  await tester.tapAt(game.kingdom.continueButton.position.toOffset());
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 500; attempt++) {
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
  expect(game.router.currentRoute.name, 'intro');
  expect(game.cutscene.isMounted, isTrue);
}
