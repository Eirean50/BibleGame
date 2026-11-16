import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
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

class _CombatGame extends FlameGame with HasKeyboardHandlerComponents {
  _CombatGame(Level1 level) : super(children: [level]);
}

void main() {
  testWidgets(
    'Sword range, facing, health bars, enemy attacks and battle reset',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.reset);
      final playerSound = _SilentSound();
      final enemySound = _SilentSound();
      final level = Level1(swordSound: playerSound, enemySound: enemySound);
      final game = _CombatGame(level);
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
      game.update(0);
      final player = level.player;
      final enemy = level.enemy;
      final bars = level.children.whereType<FighterHealthBar>().toList();
      expect(bars, hasLength(2));
      expect(player.health, 100);
      expect(enemy.health, 100);
      expect(player.isMoving, isFalse);
      expect(enemy.isMoving, isFalse);
      for (final bar in bars) {
        expect(bar.bounds.width, lessThanOrEqualTo(44));
        expect(bar.bounds.height, 5);
        expect(
          bar.bounds.bottom,
          lessThan(bar.fighter.y - bar.fighter.height / 2),
        );
      }

      final retaliation = enemy.onStrike;
      enemy.onStrike = null; // Isolate the player's hit detection first.
      enemy.position.setValues(player.x + 80, player.y);
      level.attack();
      expect(playerSound.plays, 1);
      level.attack();
      expect(playerSound.plays, 1); // Cooldown does not replay the voice.
      game.update(0.1);
      expect(enemy.health, 100); // Wind-up has not landed yet.
      game.update(0.08);
      expect(enemy.health, 75);
      expect(enemy.healthFraction, 0.75);
      expect(enemy.currentSprite, same(enemy.damageSprite));
      expect(enemy.startAttack(), isFalse);
      game.update(0.1);
      expect(enemy.health, 75); // One hit, not damage on every animation frame.
      game.update(0.3);
      expect(enemy.currentSprite, isNot(same(enemy.damageSprite)));

      player.scale.x = -1;
      enemy.position.setValues(player.x + 80, player.y);
      level.attack();
      game.update(0.5);
      expect(enemy.health, 75); // An enemy behind the sword is safe.
      player.scale.x = 1;
      enemy.position.setValues(player.x + 400, player.y);
      level.attack();
      game.update(0.5);
      expect(enemy.health, 75); // A distant enemy is safe.
      enemy.position.setValues(player.x + 80, player.y - 140);
      level.attack();
      game.update(0.5);
      expect(enemy.health, 75); // A different vertical lane is safe.

      enemy.position.setValues(player.x + 220, player.y);
      enemy.cancelAttack();
      final beforeChase = enemy.x;
      game.update(0.1);
      expect(enemy.x, lessThan(beforeChase));
      expect(enemy.isMoving, isTrue);
      enemy.onStrike = retaliation;
      enemy.position.setValues(player.x + 80, player.y);
      enemy.cancelAttack();
      final enemyPlays = enemySound.plays;
      enemy.startAttack();
      expect(enemySound.plays, enemyPlays + 1);
      game.update(0.28);
      expect(player.health, 90);
      expect(player.isHurt, isTrue);
      expect(player.currentSprite, same(player.damageSprite));
      final playerPlays = playerSound.plays;
      level.attack();
      expect(playerSound.plays, playerPlays); // Hurt state blocks attack/audio.
      game.update(0.1);
      expect(player.health, 90);

      enemy.takeDamage(1000);
      game.update(0);
      expect(enemy.health, 0);
      expect(enemy.startAttack(), isFalse);
      final defeatedPosition = enemy.position.clone();
      game.update(2);
      expect(enemy.position, defeatedPosition);
      expect(player.health, 90);
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && !level.retryButton.isMounted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
          game.update(0);
        }
      });
      expect(level.retryButton.isMounted, isTrue);
      await tester.tapAt(level.retryButton.position.toOffset());
      game.update(0);
      expect(player.health, 100);
      expect(enemy.health, 100);
      expect(enemy.isAttacking, isFalse);
      expect(player.isHurt, isFalse);
      expect(enemy.isHurt, isFalse);

      player.takeDamage(1000);
      game.update(0);
      level.attack();
      expect(player.isAttacking, isFalse);
      expect(player.healthFraction, 0);
      level.restartBattle();
      game.update(0);
      expect(player.health, 100);
      expect(enemy.health, 100);
      expect(player.scale.x, 1);
      expect(enemy.scale.x, -1);
      // AI attacks use the same audio trigger as manual attacks.
      enemy.position.setValues(player.x + 80, player.y);
      final aiPlays = enemySound.plays;
      game.update(0.81);
      expect(enemySound.plays, aiPlays + 1);
      level.stopMovement();
      expect(playerSound.stops, greaterThan(0));
      expect(enemySound.stops, greaterThan(0));
      tester.view.physicalSize = const Size(568, 320);
      await tester.pumpAndSettle();
      for (final bar in bars) {
        expect(bar.bounds.top, greaterThanOrEqualTo(0));
        expect(bar.bounds.center.dx, closeTo(bar.fighter.x, 0.001));
      }
      level.removeFromParent();
      game.update(0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(playerSound.disposed, isTrue);
      expect(enemySound.disposed, isTrue);
    },
  );
}
