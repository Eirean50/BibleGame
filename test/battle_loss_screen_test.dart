import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/battle_loss_screen.dart';
import 'package:itlective/level1.dart';
import 'package:itlective/sword_sound.dart';

class _SilentSound extends SwordSound {
  int plays = 0;
  int stops = 0;
  bool disposed = false;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposed = true;
}

class _LossGame extends FlameGame with HasKeyboardHandlerComponents {
  _LossGame(Level1 level) : super(children: [level]);
}

void main() {
  testWidgets(
    'Defeat shows the verse, blocks battle input, resizes and retries',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.reset);
      if (const bool.fromEnvironment('CAPTURE_LOSS')) {
        await tester.runAsync(() async {
          await (FontLoader('Roboto')..addFont(
                File('C:/Windows/Fonts/arial.ttf')
                    .readAsBytes()
                    .then(ByteData.sublistView),
              ))
              .load();
        });
      }
      final sound = _SilentSound();
      final ambience = _SilentSound();
      final laugh = _SilentSound();
      var continued = 0;
      final level = Level1(
        swordSound: sound,
        enemySound: _SilentSound(),
        ambienceSound: ambience,
        defeatSound: laugh,
        onContinue: () => continued++,
      );
      final game = _LossGame(level);
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
        for (var i = 0; i < 500 && !level.isMounted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      expect(level.isMounted, isTrue);
      game.pauseEngine();
      await tester.pumpAndSettle();
      expect(level.lossScreen, isNull);
      expect(laugh.plays, 0);
      // Lose while both reinforcement groups are still arriving.
      for (final enemy in level.devilTeam) {
        enemy.takeDamage(1000);
      }
      game.update(0);
      await tester.pump();
      game.update(0.1);
      expect(level.allies, hasLength(11));
      if (const bool.fromEnvironment('CAPTURE_LOSS')) {
        for (var i = 0; i < 7; i++) {
          game.update(0.1);
        }
        game.resumeEngine();
        await tester.pump(const Duration(milliseconds: 16));
        game.pauseEngine();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('build/kingdom-reinforcements.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      final stopsBeforeDefeat = ambience.stops;
      final playsBeforeDefeat = ambience.plays;
      level.player.takeDamage(1000);
      game.update(0);
      await tester.pump();
      game.update(0);
      final loss = level.lossScreen!;
      expect(level.isTransitioningToHeaven, isFalse);
      expect(level.isInHeaven, isFalse);
      expect(loss.isMounted, isTrue);
      expect(level.children.whereType<BattleLossScreen>(), hasLength(1));
      expect(level.retryButton.isMounted, isFalse);
      expect(ambience.stops, stopsBeforeDefeat);
      expect(ambience.plays, playsBeforeDefeat);
      expect(laugh.plays, 1);
      final laughingDevils = level.devilTeam
          .whereType<DevilEnemy>()
          .where((devil) => !devil.isDefeated)
          .toList();
      expect(laughingDevils, isNotEmpty);
      expect(laughingDevils.every((devil) => devil.isLaughing), isTrue);
      expect(level.enemy.isLaughing, isFalse); // Fallen enemies stay defeated.
      final firstLaughFrame = laughingDevils.first.currentSprite;
      expect(loss.revealOpacity, 0);
      await tester.tapAt(loss.retryButton.position.toOffset());
      expect(level.player.isDefeated, isTrue); // Hidden retry cannot be tapped.
      game.update(BattleLossScreen.revealDelay);
      expect(laughingDevils.first.currentSprite, isNot(same(firstLaughFrame)));
      expect(loss.revealOpacity, 0);
      game.update(BattleLossScreen.fadeDuration / 2);
      expect(loss.revealOpacity, closeTo(0.5, 0.01));
      expect(loss.isFullyVisible, isFalse);
      await tester.tapAt(loss.retryButton.position.toOffset());
      expect(level.player.isDefeated, isTrue);
      // Resizing during the reveal must preserve its progress.
      tester.view.physicalSize = const Size(568, 320);
      await tester.pump();
      expect(loss.revealOpacity, closeTo(0.5, 0.01));
      final positions = level.fighters
          .map((fighter) => fighter.position.clone())
          .toList();
      game.update(2);
      expect(loss.revealOpacity, 1);
      expect(loss.isFullyVisible, isTrue);
      expect(laugh.plays, 1); // No replay on subsequent defeat frames.
      expect(level.fighters.map((fighter) => fighter.position), positions);
      final playsBeforeInput = sound.plays;
      await tester.tapAt(level.attackButton.position.toOffset());
      await tester.tapAt(level.continueButton.position.toOffset());
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      level.continueToGenesis();
      expect(continued, 0);
      expect(sound.plays, playsBeforeInput);
      expect(level.player.isUltimateActive, isFalse);
      expect(level.children.whereType<BattleLossScreen>(), hasLength(1));

      for (final viewport in [
        const Size(960, 540),
        const Size(568, 320),
        const Size(320, 568),
      ]) {
        tester.view.physicalSize = viewport;
        await tester.pumpAndSettle();
        expect(loss.contentBounds.top, greaterThanOrEqualTo(0));
        expect(loss.contentBounds.bottom, lessThanOrEqualTo(viewport.height));
        expect(loss.contentBounds.left, greaterThanOrEqualTo(0));
        expect(loss.contentBounds.right, lessThanOrEqualTo(viewport.width));
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_LOSS')) {
          game.resumeEngine();
          await tester.pump(const Duration(milliseconds: 16));
          game.pauseEngine();
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              'build/loss-${viewport.width.toInt()}x${viewport.height.toInt()}.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      final stopsBeforeRetry = laugh.stops;
      await tester.tapAt(loss.retryButton.position.toOffset());
      await tester.pump();
      game.update(0);
      expect(level.lossScreen, isNull);
      expect(level.children.whereType<BattleLossScreen>(), isEmpty);
      expect(level.player.health, 100);
      expect(level.angelTeam, hasLength(4));
      expect(level.devilTeam, hasLength(4));
      expect(
        level.devilTeam.whereType<DevilEnemy>().any(
          (devil) => devil.isLaughing,
        ),
        isFalse,
      );
      expect(level.children.whereType<FighterHealthBar>(), hasLength(8));
      expect(ambience.plays, 2);
      expect(laugh.stops, greaterThan(stopsBeforeRetry));
      // A fresh defeat creates a fresh screen after retry.
      level.player.takeDamage(1000);
      game.update(0);
      await tester.pump();
      game.update(0);
      expect(level.lossScreen, isNot(same(loss)));
      expect(level.lossScreen!.isMounted, isTrue);
      expect(level.lossScreen!.revealOpacity, 0);
      expect(laugh.plays, 2);
      final stopsBeforePause = laugh.stops;
      final ambiencePlaysBeforePause = ambience.plays;
      final ambienceStopsBeforePause = ambience.stops;
      level.stopMovement();
      expect(ambience.stops, ambienceStopsBeforePause + 1);
      level.resumeBattleAudio();
      expect(ambience.plays, ambiencePlaysBeforePause + 1);
      expect(laugh.stops, greaterThan(stopsBeforePause));
      expect(laugh.plays, 2); // Returning to the app does not replay the laugh.
      level.removeFromParent();
      game.update(0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(laugh.disposed, isTrue);
    },
  );
}
