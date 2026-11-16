import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/old_testament_game.dart';

Future<void> enterGenesis(WidgetTester tester, OldTestamentGame game) async {
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
  // Use the real skip hit target. A second tap must never skip Genesis text.
  await tester.tapAt(game.war.skipBounds.center);
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
