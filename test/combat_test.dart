import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
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

class _CombatGame extends FlameGame with HasKeyboardHandlerComponents {
  _CombatGame(Level1 level) : super(children: [level]);
}

void main() {
  testWidgets('Angel ultimate heals, hits once, cools down, and resets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.reset);
    final ambience = _SilentSound();
    final level = Level1(
      reinforcements: 0,
      secondWaveSize: 0,
      heavenBattleEnabled: false,
      swordSound: _SilentSound(),
      enemySound: _SilentSound(),
      ambienceSound: ambience,
    );
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
    expect(ambience.plays, 1);
    final player = level.player;
    final enemy = level.enemy;
    enemy.onStrike = null;
    player.takeDamage(60);
    enemy.position.setValues(player.x - 100, player.y);
    // The radial attack also reaches behind the angel.
    await tester.tapAt(level.ultimateButton.position.toOffset());
    expect(player.health, 75);
    expect(player.isUltimateActive, isTrue);
    expect(level.ultimateCooldownRemaining, 30);
    expect(level.ultimateButton.enabled, isFalse);
    level.useUltimate();
    expect(player.health, 75);
    level.attack();
    expect(player.isAttacking, isFalse);
    game.update(0.44);
    expect(enemy.health, 100);
    game.update(0.02);
    expect(enemy.health, 50);
    game.update(1);
    expect(enemy.health, 50);
    expect(player.isUltimateActive, isFalse);
    game.update(28.53);
    expect(level.canUseUltimate, isFalse);
    game.update(0.02);
    expect(level.canUseUltimate, isTrue);
    enemy.position.setValues(player.x + player.height * 3, player.y);
    level.useUltimate();
    expect(player.health, 100); // Healing never exceeds max HP.
    game.update(0.46);
    expect(enemy.health, 50); // Outside the blast radius.
    level.stopMovement();
    expect(ambience.stops, greaterThan(0));
    level.resumeBattleAudio();
    expect(ambience.plays, 2);
    level.restartBattle();
    expect(level.ultimateCooldownRemaining, 0);
    expect(player.isUltimateActive, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    expect(player.isUltimateActive, isTrue);
    game.update(1);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyQ);
    expect(level.ultimateCooldownRemaining, 29);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final button = level.ultimateButton;
      expect(
        button.x + button.width * button.scale.x / 2,
        lessThanOrEqualTo(size.width),
      );
      expect(
        button.y - button.height * button.scale.y / 2,
        greaterThanOrEqualTo(0),
      );
    }
    final stopsBeforeDefeat = ambience.stops;
    player.takeDamage(1000);
    level.useUltimate();
    expect(player.health, 0); // Cannot resurrect with an ultimate.
    game.update(0);
    expect(ambience.stops, stopsBeforeDefeat);
    level.restartBattle();
    enemy.takeDamage(1000);
    expect(level.canUseUltimate, isFalse);
    level.removeFromParent();
    game.update(0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    expect(ambience.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Sword range, facing, health bars, enemy attacks and battle reset',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.reset);
      final playerSound = _SilentSound();
      final enemySound = _SilentSound();
      final level = Level1(
        reinforcements: 0,
        secondWaveSize: 0,
        heavenBattleEnabled: false,
        swordSound: playerSound,
        enemySound: enemySound,
        ambienceSound: _SilentSound(),
      );
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
      expect(playerSound.plays, 1); // Cooldown does not replay the swish.
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
