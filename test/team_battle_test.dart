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
import 'package:itlective/keyed_art.dart';

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
      final michael = await tester.runAsync(
        () => loadKeyedArt(AngelPlayer.artAsset),
      );
      addTearDown(michael!.image.dispose);
      expect(level.player.currentSprite.image.isCloneOf(michael.image), isTrue);
      expect(level.player.damageSprite.image.isCloneOf(michael.image), isTrue);
      expect(
        level.allies.every(
          (ally) => !ally.currentSprite.image.isCloneOf(michael.image),
        ),
        isTrue,
      );
      expect(level.devilTeam, hasLength(4));
      expect(level.children.whereType<FighterHealthBar>(), hasLength(8));
      for (final fighter in level.fighters) {
        expect(fighter.size, level.player.size);
      }
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
      final stopsBeforeWave = ambience.stops;
      final originalEnemies = level.devilTeam.toSet();
      game.update(0);
      final wave = level.devilTeam
          .where((fighter) => !originalEnemies.contains(fighter))
          .toList();
      expect(wave, hasLength(8));
      final arrivingAllies = level.allies.skip(3).toList();
      expect(arrivingAllies, hasLength(8));
      for (final ally in arrivingAllies) {
        expect(
          ally.currentSprite.image.isCloneOf(
            level.allies.first.currentSprite.image,
          ),
          isTrue,
        );
        expect(ally.currentSprite.image.isCloneOf(michael.image), isFalse);
      }
      expect(level.angelTeam, hasLength(12));
      for (final ally in arrivingAllies) {
        expect(ally.size, level.player.size);
        expect(ally.x, closeTo(level.kingdomGatePosition.x, 0.001));
        expect(
          ally.y + ally.height * 0.45,
          closeTo(level.kingdomGatePosition.y, 0.001),
        );
        expect(ally.arrivalOpacity, 0);
      }
      expect(wave.where((fighter) => fighter.x < 0), hasLength(4));
      expect(wave.where((fighter) => fighter.x > level.width), hasLength(4));
      expect(level.battleOver, isFalse);
      expect(level.retryButton.isMounted, isFalse);
      expect(ambience.stops, stopsBeforeWave);
      for (final fighter in wave) {
        expect(fighter.size, level.player.size);
        expect(fighter.health, 100);
      }
      // Mount the new components before advancing their entry animation.
      await tester.pump();
      game.update(0);
      final leftStart = wave.first.x;
      final rightStart = wave[1].x;
      game.update(0.1);
      expect(wave.first.x, greaterThan(leftStart));
      expect(wave[1].x, lessThan(rightStart));
      expect(arrivingAllies.first.arrivalOpacity, greaterThan(0));
      expect(arrivingAllies.last.arrivalOpacity, 0);
      for (var i = 0; i < 55; i++) {
        game.update(0.1);
      }
      for (final fighter in wave) {
        expect(fighter.x - fighter.width / 2, greaterThanOrEqualTo(0));
        expect(fighter.x + fighter.width / 2, lessThanOrEqualTo(level.width));
      }
      expect(level.devilTeam, hasLength(12)); // Only one follow-up wave.
      expect(level.angelTeam, hasLength(12));
      expect(arrivingAllies.every((ally) => ally.arrivalOpacity == 1), isTrue);
      final stopsBeforeVictory = ambience.stops;
      final playsBeforeVictory = ambience.plays;
      for (final devil in wave) {
        devil.takeDamage(1000);
      }
      game.update(0);
      expect(level.battleOver, isTrue);
      expect(level.isTransitioningToHeaven, isTrue);
      expect(level.canUseUltimate, isFalse);
      expect(
        level.fighters.every(
          (fighter) => !fighter.isAttacking && !fighter.isMoving,
        ),
        isTrue,
      );
      expect(ambience.stops, stopsBeforeVictory);
      expect(ambience.plays, playsBeforeVictory);
      // Finishing the battle keeps the current loop, without restarting it.
      level.resumeBattleAudio();
      expect(ambience.plays, playsBeforeVictory);
      level.stopMovement();
      expect(ambience.stops, stopsBeforeVictory + 1);
      level.resumeBattleAudio();
      expect(ambience.plays, playsBeforeVictory + 1);
      level.restartBattle();
      await tester.pump();
      game.update(0);
      expect(level.isTransitioningToHeaven, isFalse);
      expect(level.isInHeaven, isFalse);
      expect(level.devilTeam, hasLength(4));
      expect(level.angelTeam, hasLength(4));
      expect(level.children.whereType<FighterHealthBar>(), hasLength(8));
      expect(level.battleOver, isFalse);
      expect(level.ultimateCooldownRemaining, 0);
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        for (final fighter in level.fighters) {
          expect(fighter.size, level.player.size);
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
