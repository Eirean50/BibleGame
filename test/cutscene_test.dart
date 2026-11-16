import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/creation_backdrop.dart';
import 'package:itlective/cutscene_component.dart';
import 'package:itlective/level1.dart';
import 'package:itlective/eden_cutscene.dart';
import 'package:itlective/old_testament_game.dart';

import 'story_test_helpers.dart';

Future<OldTestamentGame> mountGame(WidgetTester tester) async {
  final game = OldTestamentGame(playWarVideo: false);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await enterGenesis(tester, game);
  game.pauseEngine();
  await tester.pumpAndSettle();
  expect(game.cutscene.isMounted, isTrue);
  return game;
}

Future<void> disposeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Screen taps skip, advance, restore typing and finish once', (
    tester,
  ) async {
    final game = await mountGame(tester);
    final scene = game.cutscene;
    expect(scene.backdrop.layers[CreationStage.seaLife]!.birds, hasLength(2));
    final formation =
        scene.backdrop.layers[CreationStage.people]!.humanCreation!;
    expect(creationScript, hasLength(15));
    expect(scene.textIndex, 0);
    expect(scene.isTyping, isTrue);
    final before = scene.dialogue.currentChar;
    game.update(0.14);
    expect(scene.dialogue.currentChar, greaterThan(before));

    // Tap above the panel: input covers the entire screen.
    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    expect(scene.textIndex, 0);
    expect(scene.isTyping, isFalse);
    expect(scene.dialogue.currentChar, creationScript.first.length);
    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    expect(scene.textIndex, 1);
    expect(scene.isTyping, isTrue);
    expect(scene.dialogue.currentChar, 0);

    // Natural completion never advances without another tap.
    game.update(20);
    expect(scene.isTyping, isFalse);
    expect(scene.textIndex, 1);
    await tester.tapAt(const Offset(100, 100));
    await tester.pump();
    expect(scene.textIndex, 2);
    game.update(0); // Mount the newly queued opacity effect.
    game.update(0.6);
    final light = scene.backdrop.layers[CreationStage.light]!;
    expect(light.opacity, greaterThan(0));
    expect(light.opacity, lessThan(1));
    game.update(0.7);
    expect(light.opacity, closeTo(1, 0.001));

    for (var index = 2; index < creationScript.length; index++) {
      expect(scene.textIndex, index);
      if (scene.isTyping) scene.advance();
      expect(scene.dialogue.text, creationScript[index]);
      if (index == 13) {
        // Hidden characters must still start as dust after earlier dialogue.
        expect(formation.currentStage, 0);
        expect(formation.isFormed, isFalse);
        game.update(0); // Mount the queued fade effects.
        game.update(1.3);
        game.update(3);
        expect(formation.currentStage, inExclusiveRange(0, 5));
        game.update(8);
        expect(formation.isFormed, isTrue);
        game.update(20);
        expect(formation.currentStage, 5); // Never loop back to dust.
      }
      if (index < creationScript.length - 1) scene.advance();
    }
    expect(game.router.currentRoute.name, 'intro');
    expect(scene.isFinished, isFalse);
    scene.advance();
    scene.advance();
    scene.finishCutscene();
    // Creation now flows into Eden before Level1.
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 200; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        game.update(0);
        if (game.descendants().whereType<EdenCutscene>().isNotEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    game.update(0);
    expect(scene.isFinished, isTrue);
    expect(game.router.currentRoute.name, 'eden');
    final eden = game.eden;
    expect(eden.textIndex, 0);
    expect(eden.backdrop.cameraZoom, 3);
    for (var i = 0; i < edenScript.length; i++) {
      expect(eden.textIndex, i);
      expect(eden.isTyping, isTrue);
      eden.advance();
      expect(eden.dialogue.text, edenScript[i]);
      expect(eden.isTyping, isFalse);
      eden.advance();
    }
    // Rapid taps cannot leave before the camera reveals all three figures.
    expect(eden.isFinished, isFalse);
    game.update(6);
    expect(eden.backdrop.cameraZoom, closeTo(2, 0.001));
    game.update(6);
    expect(eden.backdrop.cameraZoom, 1);
    expect(eden.backdrop.isRevealed, isTrue);
    eden.advance();
    eden.advance();
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 200; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        game.update(0);
        if (game.descendants().whereType<Level1>().isNotEmpty) break;
      }
    });
    await tester.pumpAndSettle();
    expect(game.router.currentRoute.name, 'Level1');
    expect(game.router.stack, hasLength(1));
    expect(game.descendants().whereType<Level1>(), hasLength(1));
    final level = game.descendants().whereType<Level1>().single;
    expect(level.backdrop.isRevealed, isTrue);
    expect(level.backdrop.currentFrame, 5);
    game.update(30);
    expect(level.backdrop.currentFrame, 5);
    await disposeGame(tester);
  });

  testWidgets('Eden keeps camera progress and fits dialogue after resizing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.reset);
    final scene = EdenCutscene(onFinished: () {});
    final game = FlameGame(children: [scene]);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 200; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (scene.isMounted) break;
      }
    });
    expect(scene.isMounted, isTrue);
    game.pauseEngine();
    expect(scene.backdrop.isGroupVisible, isFalse);
    game.update(2);
    expect(scene.backdrop.isGroupVisible, isFalse);
    expect(scene.backdrop.currentFrame, 0);
    for (var step = 0; step < 240 && !scene.backdrop.isGroupVisible; step++) {
      game.update(0.05);
    }
    expect(scene.backdrop.isGroupVisible, isTrue);
    expect(
      scene.backdrop.currentFrame,
      0,
    ); // Hidden time does not advance poses.
    game.update(GardenBackdrop.frameDuration + 0.01);
    expect(scene.backdrop.currentFrame, 1);
    final zoom = scene.backdrop.cameraZoom;
    for (var line = 0; line < edenScript.length; line++) {
      expect(scene.textIndex, line);
      for (final size in [
        const Size(320, 568),
        const Size(568, 320),
        const Size(960, 540),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(scene.backdrop.cameraZoom, zoom);
        expect(
          scene.dialogue.y + scene.dialogue.height,
          lessThanOrEqualTo(size.height - 40),
        );
        expect(
          scene.dialogue.x + scene.dialogue.width,
          lessThanOrEqualTo(size.width),
        );
        expect(tester.takeException(), isNull);
      }
      if (scene.isTyping) scene.advance();
      if (line < edenScript.length - 1) scene.advance();
    }
    game.update(20);
    expect(scene.backdrop.cameraZoom, 1);
    expect(scene.backdrop.currentFrame, 5);
    expect(scene.backdrop.isAnimationFinished, isTrue);
    game.update(30);
    expect(scene.backdrop.cameraZoom, 1); // No looping camera motion.
    expect(scene.backdrop.currentFrame, 5); // Hold the final pose forever.
    await disposeGame(tester);
  });

  testWidgets('Every script chunk fits portrait and landscape after resizing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final game = await mountGame(tester);
    final scene = game.cutscene;

    for (var index = 0; index < creationScript.length; index++) {
      for (final size in [
        const Size(320, 568),
        const Size(568, 320),
        const Size(960, 432),
      ]) {
        final charsBefore = scene.dialogue.currentChar;
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(scene.dialogue.currentChar, charsBefore);
        expect(scene.dialoguePanel.y, greaterThanOrEqualTo(0));
        expect(scene.dialogue.x, greaterThanOrEqualTo(0));
        expect(
          scene.dialogue.x + scene.dialogue.width,
          lessThanOrEqualTo(size.width),
        );
        expect(
          scene.dialogue.y + scene.dialogue.height,
          lessThanOrEqualTo(size.height - 40),
        );
        expect(tester.takeException(), isNull);
      }
      scene.advance(); // Reveal.
      if (index < creationScript.length - 1) scene.advance();
    }
    await disposeGame(tester);
  });
}
