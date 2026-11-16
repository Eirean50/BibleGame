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

class _FakeSwordSound extends SwordSound {
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

class _MovementGame extends FlameGame with HasKeyboardHandlerComponents {
  _MovementGame(Level1 level) : super(children: [level]);
}

void main() {
  testWidgets('Angel moves with keyboard and touch, stops, and stays visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.reset);
    if (const bool.fromEnvironment('CAPTURE_KINGDOM')) {
      await tester.runAsync(() async {
        final font = File('C:/Windows/Fonts/arial.ttf');
        if (await font.exists()) {
          await (FontLoader(
            'Roboto',
          )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
        }
      });
    }
    final sound = _FakeSwordSound();
    var continued = 0;
    final level = Level1(swordSound: sound, onContinue: () => continued++);
    final game = _MovementGame(level);
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: captureKey,
          child: GameWidget(game: game),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (level.isMounted) break;
      }
    });
    expect(level.isMounted, isTrue);
    // This test isolates player controls; combat has its own encounter test.
    level.enemy.takeDamage(KingdomFighter.maxHealth);
    game.pauseEngine();
    await tester.pumpAndSettle();
    game.update(0);
    final spawn = level.player.position.clone();
    expect(spawn.x, closeTo(960 * 0.32, 0.001));
    expect(spawn.y, closeTo(540 * 0.62, 0.001));
    game.update(1);
    expect(level.player.position, spawn);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    game.update(0.2);
    final straightDistance = level.player.position.distanceTo(spawn);
    expect(straightDistance, closeTo(level.movementSpeed * 0.2, 0.001));
    expect(level.player.isMoving, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    final stopped = level.player.position.clone();
    game.update(0.5);
    expect(level.player.position, stopped);
    expect(level.player.isMoving, isFalse);

    level.player.position.setFrom(spawn);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    game.update(0.2);
    expect(
      level.player.position.distanceTo(spawn),
      closeTo(straightDistance, 0.001),
    );
    expect(level.player.y, lessThan(spawn.y));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    game.update(0.2);
    expect(level.player.scale.x, -1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    final beforeDown = level.player.y;
    game.update(0.1);
    expect(level.player.y, greaterThan(beforeDown));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);

    for (final cancel in [false, true]) {
      level.player.position.setFrom(spawn);
      final gesture = await tester.startGesture(
        level.joystick.position.toOffset(),
      );
      // Cross the touch slop to begin a drag, then move the held joystick.
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(40, 0));
      game.update(0); // Let the joystick publish its new direction.
      game.update(0.2);
      expect(level.player.x, greaterThan(spawn.x));
      if (cancel) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      game.update(0);
      final released = level.player.position.clone();
      game.update(1);
      expect(level.player.position, released);
      expect(level.player.isMoving, isFalse);
    }

    for (final viewport in [
      const Size(320, 568),
      const Size(568, 320),
      const Size(960, 540),
    ]) {
      tester.view.physicalSize = viewport;
      await tester.pumpAndSettle();
      expect(level.backdrop.width, greaterThanOrEqualTo(viewport.width));
      expect(level.backdrop.height, greaterThanOrEqualTo(viewport.height));
      for (final key in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
      ]) {
        await tester.sendKeyDownEvent(key);
        game.update(20);
        await tester.sendKeyUpEvent(key);
        expect(
          level.player.x - level.player.width / 2,
          greaterThanOrEqualTo(0),
        );
        expect(
          level.player.y - level.player.height / 2,
          greaterThanOrEqualTo(0),
        );
        expect(
          level.player.x + level.player.width / 2,
          lessThanOrEqualTo(viewport.width),
        );
        expect(
          level.player.y + level.player.height / 2,
          lessThanOrEqualTo(viewport.height),
        );
      }
      expect(tester.takeException(), isNull);
    }

    expect(sound.plays, 0); // Movement-pad gestures never attack.
    await tester.tapAt(level.joystick.position.toOffset());
    expect(sound.plays, 0);
    level.player.position.setFrom(spawn);
    await tester.tapAt(const Offset(700, 250));
    expect(level.player.isAttacking, isTrue);
    expect(sound.plays, 1);
    expect(continued, 0);
    await tester.tapAt(const Offset(700, 250));
    expect(sound.plays, 1); // Rapid taps cannot overlap the swing/sound.
    game.update(AngelPlayer.attackDuration + 0.01);
    expect(level.player.isAttacking, isFalse);
    await tester.tapAt(level.attackButton.position.toOffset());
    expect(sound.plays, 2);
    game.update(AngelPlayer.attackDuration + 0.01);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    expect(sound.plays, 3);
    game.update(AngelPlayer.attackDuration + 0.01);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    expect(sound.plays, 3); // Holding Space does not spam attacks.
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    expect(sound.plays, 4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    level.stopMovement();
    expect(level.player.isAttacking, isFalse);
    expect(sound.stops, 1);

    if (const bool.fromEnvironment('CAPTURE_KINGDOM')) {
      for (final moving in [false, true]) {
        level.restartBattle();
        if (moving) {
          level.enemy.x = level.player.x + level.player.height * 1.65;
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
        }
        game.update(0.05);
        game.resumeEngine();
        await tester.pump(const Duration(milliseconds: 16));
        game.pauseEngine();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await Directory('build').create(recursive: true);
          final name = moving ? 'kingdom-movement-preview' : 'kingdom-preview';
          await File('build/$name.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
        if (moving) await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      }
    }
    final playsBeforeContinue = sound.plays;
    await tester.tapAt(level.continueButton.position.toOffset());
    level.continueToGenesis();
    level.attack();
    expect(continued, 1);
    expect(sound.plays, playsBeforeContinue);
    expect(level.player.isAttacking, isFalse);
    level.removeFromParent();
    game.update(0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(sound.disposed, isTrue);
  });
}
