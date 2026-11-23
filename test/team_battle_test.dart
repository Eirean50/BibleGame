import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _BattleGame extends FlameGame with HasKeyboardHandlerComponents {
  _BattleGame(Level1 level) : super(children: [level]);
}

void main() {
  testWidgets(
    'Teams fight, retarget, receive the ultimate, and reset together',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.reset);
      final ambience = _SilentSound();
      final level = Level1(
        swordSound: _SilentSound(),
        enemySound: _SilentSound(),
        ambienceSound: ambience,
      );
      final game = _BattleGame(level);
      final key = GlobalKey();
      if (const bool.fromEnvironment('CAPTURE_BATTLE')) {
        await tester.runAsync(() async {
          final font = File('C:/Windows/Fonts/arial.ttf');
          await (FontLoader(
            'Roboto',
          )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
        });
      }
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
      expect(level.angelTeam, hasLength(4));
      expect(level.devilTeam, hasLength(4));
      expect(level.children.whereType<FighterHealthBar>(), hasLength(8));
      expect(ambience.plays, 1);
      final start = level.allies.first.position.clone();
      for (var i = 0; i < 140; i++) {
        game.update(0.05);
      }
      expect(level.allies.first.position, isNot(start));
      expect(level.angelTeam.any((fighter) => fighter.health < 100), isTrue);
      expect(level.devilTeam.any((fighter) => fighter.health < 100), isTrue);

      if (const bool.fromEnvironment('CAPTURE_BATTLE')) {
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
          await File('build/team-battle-preview.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }

      level.restartBattle();
      level.enemy.takeDamage(1000);
      expect(
        level.battleOver,
        isFalse,
      ); // The other devils keep the battle alive.
      expect(level.canUseUltimate, isTrue);
      expect(level.retryButton.isMounted, isFalse);
      final survivor = level.additionalEnemies.first;
      for (final devil in level.additionalEnemies.skip(1)) {
        devil.takeDamage(1000);
      }
      for (final ally in level.allies.skip(1)) {
        ally.takeDamage(1000);
      }
      level.player.position.setValues(150, 420);
      level.allies.first.position.setValues(420, 220);
      survivor.position.setValues(500, 220);
      game.update(0);
      expect(level.retryButton.isMounted, isFalse);
      for (var i = 0; i < 100; i++) {
        game.update(0.05);
      }
      expect(survivor.health, lessThan(100));
      expect(level.allies.first.health, lessThan(100));

      level.restartBattle();
      expect(level.fighters.every((fighter) => fighter.health == 100), isTrue);
      for (final ally in level.allies) {
        ally.position.setFrom(level.player.position);
        ally.takeDamage(50);
      }
      level.allies.last.takeDamage(1000);
      for (final devil in level.devilTeam) {
        devil.position.setValues(level.player.x + 100, level.player.y);
      }
      level.useUltimate();
      expect(level.allies.first.health, 85);
      expect(
        level.allies.last.health,
        0,
      ); // Healing cannot revive fallen allies.
      game.update(0.46);
      expect(level.devilTeam.every((fighter) => fighter.health == 50), isTrue);
      expect(level.ultimateCooldownRemaining, closeTo(29.54, 0.001));
      for (final devil in level.devilTeam) {
        devil.takeDamage(1000);
      }
      game.update(0);
      expect(level.battleOver, isTrue);
      expect(level.canUseUltimate, isFalse);
      expect(
        level.fighters.every(
          (fighter) => !fighter.isAttacking && !fighter.isMoving,
        ),
        isTrue,
      );
      expect(ambience.stops, greaterThan(0));
      level.restartBattle();
      game.update(0);
      expect(level.battleOver, isFalse);
      expect(level.ultimateCooldownRemaining, 0);
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        for (final fighter in level.fighters) {
          expect(fighter.x - fighter.width / 2, greaterThanOrEqualTo(0));
          expect(fighter.x + fighter.width / 2, lessThanOrEqualTo(size.width));
          expect(fighter.y - fighter.height / 2, greaterThanOrEqualTo(0));
          expect(
            fighter.y + fighter.height / 2,
            lessThanOrEqualTo(size.height),
          );
        }
      }
      level.removeFromParent();
      game.update(0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      expect(ambience.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
