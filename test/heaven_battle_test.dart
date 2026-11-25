import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/level1.dart';
import 'package:itlective/sword_sound.dart';

class _Sound extends SwordSound {
  int plays = 0;
  int stops = 0;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async {}
}

class _BattleGame extends FlameGame with HasKeyboardHandlerComponents {
  _BattleGame(Level1 level) : super(children: [level]);
}

Future<void> _capture(WidgetTester tester, Level1 level, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_HEAVEN')) return;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    level.renderTree(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      level.width.ceil(),
      level.height.ceil(),
    );
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('build/heaven-$name.png').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
    picture.dispose();
  });
}

void main() {
  testWidgets(
    'Kingdom victory fades into a fresh playable heaven battle once',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.reset);
      if (const bool.fromEnvironment('CAPTURE_HEAVEN')) {
        await tester.runAsync(() async {
          await (FontLoader('Roboto')..addFont(
                File('C:/Windows/Fonts/arial.ttf')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              ))
              .load();
        });
      }
      final ambience = _Sound();
      final attacks = _Sound();
      var continued = 0;
      final level = Level1(
        secondWaveSize: 2,
        swordSound: attacks,
        enemySound: _Sound(),
        defeatSound: _Sound(),
        ambienceSound: ambience,
        onContinue: () => continued++,
      );
      final game = _BattleGame(level);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.runAsync(() async {
        for (var i = 0; i < 500 && !level.isMounted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      expect(level.isMounted, isTrue);
      game.pauseEngine();
      await tester.pumpAndSettle();
      final kingdomImage = level.backdrop.sprite!.image;
      final heavenImage = await tester.runAsync(
        () => Flame.images.load('heaven.png'),
      );
      void defeatEnemies() {
        for (final enemy in level.devilTeam) {
          enemy.takeDamage(1000);
        }
        game.update(0);
      }

      level.player.takeDamage(30);
      level.allies.first.takeDamage(1000);
      defeatEnemies();
      expect(level.isTransitioningToHeaven, isFalse); // Reinforcements remain.
      expect(
        level.devilTeam.where((fighter) => !fighter.isDefeated),
        hasLength(2),
      );
      await tester.pump();
      game.update(0);
      defeatEnemies();
      expect(level.isTransitioningToHeaven, isTrue);
      expect(level.isInHeaven, isFalse);
      expect(level.heavenTransitionOpacity, 0);
      expect(level.retryButton.isMounted, isFalse);
      expect(ambience.plays, 1);
      expect(ambience.stops, 0);
      await tester.pump();
      game.update(1);
      expect(level.heavenTransitionOpacity, closeTo(0.5, 0.01));
      expect(level.backdrop.sprite!.image, same(kingdomImage));
      await _capture(tester, level, 'leaving-kingdom');
      final frozen = level.player.position.clone();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      level.attack();
      level.useUltimate();
      level.continueToGenesis();
      game.update(0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(level.player.position, frozen);
      expect(level.player.isAttacking, isFalse);
      expect(level.player.isUltimateActive, isFalse);
      expect(attacks.plays, 0);
      expect(continued, 0);

      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      expect(level.heavenTransitionOpacity, closeTo(0.5, 0.01));
      game.update(1);
      expect(level.isInHeaven, isTrue);
      expect(level.isTransitioningToHeaven, isTrue);
      expect(level.heavenTransitionOpacity, 1);
      expect(level.backdrop.sprite!.image.isCloneOf(heavenImage!), isTrue);
      expect(level.angelTeam, hasLength(4));
      expect(level.devilTeam, hasLength(4));
      expect(level.fighters.every((fighter) => fighter.health == 100), isTrue);
      expect(level.ultimateCooldownRemaining, 0);
      expect(level.canUseUltimate, isFalse);
      await tester.pump();
      game.update(0);
      expect(level.children.whereType<FighterHealthBar>(), hasLength(8));
      tester.view.physicalSize = const Size(960, 540);
      await tester.pumpAndSettle();
      game.update(1);
      expect(level.heavenTransitionOpacity, closeTo(0.5, 0.01));
      await _capture(tester, level, 'arriving');
      expect(level.fighters.every((fighter) => fighter.health == 100), isTrue);
      game.update(1);
      game.update(0);
      expect(level.isTransitioningToHeaven, isFalse);
      expect(level.heavenTransitionOpacity, 0);
      expect(level.battleOver, isFalse);
      expect(level.canUseUltimate, isTrue);
      expect(ambience.plays, 1);
      expect(ambience.stops, 0);
      await _capture(tester, level, 'battle');
      final enemyPosition = level.additionalEnemies.first.position.clone();
      game.update(0.1);
      expect(level.additionalEnemies.first.position, isNot(enemyPosition));
      level.enemy.position.setValues(level.player.x + 80, level.player.y);
      level.attack();
      game.update(0.18);
      expect(level.enemy.health, 75);
      expect(attacks.plays, 1);

      level.player.takeDamage(1000);
      game.update(0);
      await tester.pump();
      game.update(0);
      expect(level.lossScreen, isNotNull);
      level.restartBattle();
      await tester.pump();
      game.update(0);
      expect(level.isInHeaven, isTrue); // Retry the current arena.
      expect(level.lossScreen, isNull);
      expect(level.player.health, 100);
      expect(level.backdrop.sprite!.image.isCloneOf(heavenImage), isTrue);
      for (final viewport in [const Size(320, 568), const Size(568, 320)]) {
        tester.view.physicalSize = viewport;
        await tester.pumpAndSettle();
        expect(level.backdrop.width, greaterThanOrEqualTo(viewport.width));
        expect(level.backdrop.height, greaterThanOrEqualTo(viewport.height));
        for (final fighter in level.fighters) {
          expect(fighter.size, level.player.size);
          expect(fighter.x - fighter.width / 2, greaterThanOrEqualTo(0));
          expect(
            fighter.x + fighter.width / 2,
            lessThanOrEqualTo(viewport.width),
          );
        }
      }
      defeatEnemies();
      await tester.pump();
      game.update(0);
      defeatEnemies();
      game.update(Level1.heavenTransitionDuration + 1);
      await tester.pump();
      game.update(0);
      expect(level.isInHeaven, isTrue);
      expect(
        level.isTransitioningToHeaven,
        isFalse,
      ); // No endless arena resets.
      expect(level.battleOver, isTrue);
      expect(level.retryButton.isMounted, isTrue);
      level.continueToGenesis();
      expect(continued, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );
}
