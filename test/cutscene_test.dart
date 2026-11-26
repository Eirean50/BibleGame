import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/creation_backdrop.dart';
import 'package:itlective/cutscene_component.dart';
import 'package:itlective/level1.dart';
import 'package:itlective/eden_cutscene.dart';
import 'package:itlective/old_testament_game.dart';
import 'package:itlective/genesis_music.dart';
import 'package:itlective/garden_story.dart';
import 'package:itlective/sword_sound.dart';

import 'story_test_helpers.dart';

class _MusicSound extends SwordSound {
  int plays = 0;
  int disposals = 0;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async => disposals++;
}

Future<OldTestamentGame> mountGame(
  WidgetTester tester, {
  GenesisMusic? music,
}) async {
  final game = OldTestamentGame(playWarVideo: false, genesisMusic: music);
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
    final soundtrack = _MusicSound();
    final serpentTrack = _MusicSound();
    final game = await mountGame(
      tester,
      music: GenesisMusic(sound: soundtrack, serpentSound: serpentTrack),
    );
    expect(soundtrack.plays, 1);
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
    // Gameplay has already finished; Creation flows into Eden.
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 200; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        game.update(0);
        if (game.descendants().whereType<EdenCutscene>().any(
          (scene) => scene.isMounted,
        )) {
          break;
        }
      }
    });
    await tester.pumpAndSettle();
    game.update(0);
    expect(scene.isFinished, isTrue);
    expect(game.router.currentRoute.name, 'eden');
    expect(soundtrack.plays, 1); // Keep the same music through scene changes.
    expect(serpentTrack.plays, 0);
    final eden = game.eden;
    expect(eden.textIndex, 0);
    expect(eden.backdrop.garden.cameraZoom, 3);
    for (var i = 0; i < 3; i++) {
      expect(eden.textIndex, i);
      expect(eden.isTyping, isTrue);
      eden.advance();
      expect(eden.dialogue.text, edenScript[i]);
      expect(eden.isTyping, isFalse);
      eden.advance();
    }
    // Keep the same mounted scene through the complete garden continuation.
    expect(eden.isFinished, isFalse);
    expect(eden.textIndex, 2);
    game.update(6);
    expect(eden.backdrop.garden.cameraZoom, closeTo(2, 0.001));
    game.update(6);
    expect(eden.backdrop.garden.cameraZoom, 1);
    expect(eden.backdrop.garden.isRevealed, isTrue);
    eden.advance();
    for (var i = 0; i < gardenStoryScript.length; i++) {
      expect(game.router.currentRoute.name, 'eden');
      expect(eden.isMounted, isTrue);
      expect(eden.backdrop.isMounted, isTrue);
      expect(eden.dialogue.isMounted, isTrue);
      expect(eden.textIndex, i + 3);
      expect(eden.dialogue.text, gardenStoryScript[i]);
      expect(eden.backdrop.currentScene, i);
      if (eden.isTyping) eden.advance();
      game.update(GardenStoryBackdrop.transitionDuration);
      if (i == 1) game.update(GardenStoryBackdrop.treeHoldDuration);
      if (i >= 3) {
        game.update(10);
        game.update(10);
      }
      if (eden.isTyping) eden.advance();
      eden.advance();
    }
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 200; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        game.update(0);
        if (game.descendants().whereType<GardenEnding>().any(
          (scene) => scene.isMounted,
        )) {
          break;
        }
      }
    });
    await tester.pumpAndSettle();
    expect(game.router.currentRoute.name, 'ending');
    expect(serpentTrack.plays, 1);
    expect(soundtrack.plays, 1);
    expect(game.router.stack, hasLength(1));
    expect(game.descendants().whereType<Level1>(), isEmpty);
    final ending = game.descendants().whereType<GardenEnding>().single;
    expect(ending.backdrop.isLoaded, isTrue);
    game.update(30);
    expect(ending.backdrop.isMounted, isTrue);
    await disposeGame(tester);
    expect(soundtrack.disposals, 1);
    expect(serpentTrack.disposals, 1);
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
    expect(scene.backdrop.garden.isGroupVisible, isFalse);
    game.update(2);
    expect(scene.backdrop.garden.isGroupVisible, isFalse);
    expect(scene.backdrop.garden.currentFrame, 0);
    for (
      var step = 0;
      step < 240 && !scene.backdrop.garden.isGroupVisible;
      step++
    ) {
      game.update(0.05);
    }
    expect(scene.backdrop.garden.isGroupVisible, isTrue);
    expect(
      scene.backdrop.garden.currentFrame,
      0,
    ); // Hidden time does not advance poses.
    game.update(GardenBackdrop.frameDuration + 0.01);
    expect(scene.backdrop.garden.currentFrame, 1);
    final zoom = scene.backdrop.garden.cameraZoom;
    for (var line = 0; line < edenScript.length; line++) {
      expect(scene.textIndex, line);
      for (final size in [
        const Size(320, 568),
        const Size(568, 320),
        const Size(960, 540),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(scene.backdrop.garden.cameraZoom, line <= 2 ? zoom : 1);
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
      if (line == 2) {
        game.update(20);
      }
      if (line >= 4) {
        game.update(10);
        game.update(10);
      }
      if (line < edenScript.length - 1) scene.advance();
    }
    game.update(20);
    expect(scene.backdrop.garden.cameraZoom, 1);
    expect(scene.backdrop.garden.currentFrame, 5);
    expect(scene.backdrop.garden.isAnimationFinished, isTrue);
    game.update(30);
    expect(scene.backdrop.garden.cameraZoom, 1); // No looping camera motion.
    expect(
      scene.backdrop.garden.currentFrame,
      5,
    ); // Hold the final pose forever.
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
