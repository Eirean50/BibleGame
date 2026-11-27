import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/creation_backdrop.dart';
import 'package:itlective/garden_story.dart';
import 'package:itlective/genesis_audio.dart';
import 'package:itlective/sword_sound.dart';

class _CueSound extends SwordSound {
  int plays = 0;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

Future<void> capturePreview(
  WidgetTester tester,
  FlameGame game,
  GlobalKey key,
  String name,
) async {
  if (!const bool.fromEnvironment('GENESIS_PREVIEW')) return;
  game.resumeEngine();
  await tester.pump(const Duration(milliseconds: 1));
  game.pauseEngine();
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory('build').create(recursive: true);
    await File('build/$name.png').writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
  });
}

void main() {
  testWidgets('Screen taps continue from Genesis 3:1 through 3:4', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.reset);
    var finishes = 0;
    final story = GardenStory(onFinished: () => finishes++);
    final game = FlameGame(children: [story]);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(() async {
      for (var i = 0; i < 500 && !story.isMounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    expect(story.isMounted, isTrue);
    game.pauseEngine();
    for (var line = 0; line < 11; line++) {
      expect(story.textIndex, line);
      if (story.isTyping) story.advance();
      game.update(20);
      game.update(20);
      story.advance();
    }
    game.update(15);
    expect(story.dialogue.text, startsWith('[3:1]'));
    expect(story.canAdvance, isTrue);
    for (var line = 11; line <= 14; line++) {
      expect(story.textIndex, line);
      expect(story.dialogue.text, startsWith('[3:${line - 10}]'));
      if (line == 13) {
        expect(
          story.isTyping,
          isFalse,
        ); // Read the whole warning during the hold.
        game.update(GardenStoryBackdrop.transitionDuration);
        expect(story.backdrop.treeOpacity, 1);
        game.update(4.99);
        await tester.tapAt(const Offset(480, 470));
        expect(story.textIndex, 13); // Taps cannot shorten the five seconds.
        game.update(0.01);
        expect(
          story.textIndex,
          14,
        ); // Return automatically without another tap.
        expect(story.backdrop.encounter.isWalking, isFalse);
        continue;
      }
      // Exercise the actual pointer dispatcher, both on the scene and panel.
      if (story.isTyping) await tester.tapAt(const Offset(480, 470));
      game.update(3);
      await tester.tapAt(
        line.isEven ? const Offset(480, 470) : const Offset(100, 100),
      );
      await tester.pump();
    }
    expect(finishes, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rapid screen taps cannot skip the forbidden tree fade', (
    tester,
  ) async {
    final story = GardenStory(onFinished: () {});
    final game = FlameGame(children: [story]);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(() async {
      for (var i = 0; i < 500 && !story.isMounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    expect(story.isMounted, isTrue);
    game.pauseEngine();
    await tester.tapAt(const Offset(100, 100)); // Reveal the first line.
    await tester.tapAt(const Offset(100, 100)); // Enter the tree scene.
    expect(story.textIndex, 1);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(100, 100));
    }
    expect(story.textIndex, 1);
    expect(story.backdrop.currentScene, 1);
    // Exercise the real frame loop, not a direct call to game.update().
    game.resumeEngine();
    for (var i = 0; i < 190; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    game.pauseEngine();
    expect(story.backdrop.isTransitioning, isFalse);
    expect(story.backdrop.treeOpacity, 1);
    expect(story.textIndex, 1);
    await tester.tapAt(const Offset(100, 100));
    expect(story.textIndex, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Garden continues through sleep, rib light, Eve rising and reunion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 540);
      addTearDown(tester.view.reset);
      if (const bool.fromEnvironment('GENESIS_PREVIEW')) {
        await tester.runAsync(() async {
          final font = File('C:/Windows/Fonts/consola.ttf');
          if (await font.exists()) {
            await (FontLoader(
              'monospace',
            )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
          }
        });
      }
      var finishes = 0;
      var serpentCues = 0;
      final cue = _CueSound();
      final story = GardenStory(
        onSerpentScene: () => serpentCues++,
        onFinished: () => finishes++,
        audio: GenesisAudio(reveal: cue),
      );
      final game = FlameGame(children: [story]);
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
        for (var i = 0; i < 500 && !story.isMounted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      expect(story.isMounted, isTrue);
      game.pauseEngine();
      final naming = story.backdrop.naming;
      expect(naming.layers.containsKey(CreationStage.animals), isFalse);
      expect(naming.layers.containsKey(CreationStage.people), isFalse);
      expect(naming.layers[CreationStage.seaLife]!.birds, hasLength(2));
      expect(naming.layers[CreationStage.angels]!.angels, hasLength(3));
      expect(naming.layers[CreationStage.seaLife]!.showFish, isFalse);
      expect(naming.layers.values.every((layer) => layer.opacity == 1), isTrue);
      game.update(10);
      expect(naming.adam.currentFrame, 0); // No invisible animation time.

      for (var line = 0; line < gardenStoryScript.length; line++) {
        expect(story.textIndex, line);
        expect(story.backdrop.currentScene, line);
        expect(story.dialogue.text, gardenStoryScript[line]);
        if (line >= 12) {
          game.update(0);
          expect(story.isNarrationVisible, isTrue);
          expect(story.backdrop.encounter.hasArrived, isTrue);
          expect(story.backdrop.encounter.isWalking, isFalse);
          expect(story.backdrop.encounter.eveProgress, closeTo(0.5, 0.001));
          expect(story.backdrop.encounter.forbiddenOpacity, 0);
          expect(story.backdrop.encounter.isSpeaking, line == 14);
          expect(serpentCues, 1); // No replay of the entrance or soundtrack.
          if (line == 12) expect(story.backdrop.isTransitioning, isFalse);
        }
        if (story.isTyping) story.advance();
        if (const [1, 2, 3, 5, 8, 10, 13, 14].contains(line)) {
          expect(story.backdrop.isTransitioning, isTrue);
          if (line == 2) {
            story.advance();
            expect(finishes, 0); // A rapid tap cannot cut off the last fade.
          }
          game.update(1);
          expect(story.backdrop.isTransitioning, isTrue);
          game.update(1);
          expect(story.backdrop.isTransitioning, isFalse);
          if (line == 1 || line == 10 || line == 13) {
            story.advance();
            expect(
              story.textIndex,
              line,
            ); // Hold the fully visible tree briefly.
            game.update(GardenStoryBackdrop.treeHoldDuration);
            expect(story.backdrop.treeOpacity, 1);
          }
        }
        if (line == 2) {
          game.update(4);
          expect(naming.adam.currentFrame, inInclusiveRange(3, 10));
        }
        final adam = story.backdrop.sleeping.figures;
        if (line == 3) {
          expect(cue.plays, 0);
          expect(adam.isAsleep, isFalse);
          story.advance();
          expect(story.textIndex, 3);
          game.update(2.6);
          expect(adam.isAsleep, isTrue);
          expect(cue.plays, 1);
          game.update(1.6);
          expect(adam.shineIntensity, closeTo(1, 0.01));
          await capturePreview(tester, game, key, 'genesis-rib-glow');
          game.update(1.6);
          expect(adam.shineFinished, isTrue);
        }
        if (line == 4) {
          expect(adam.isEveVisible, isTrue);
          expect(adam.eveFinished, isFalse);
          story.advance();
          expect(story.textIndex, 4);
          game.update(2);
          await capturePreview(tester, game, key, 'genesis-eve-rising');
          game.update(3.6);
          expect(adam.eveFinished, isTrue);
          expect(cue.plays, 1);
        }
        if (line == 5) {
          game.update(5);
          expect(story.backdrop.couple.currentFrame, 11);
        }
        if (line == 8) {
          expect(story.backdrop.garden.includeEve, isFalse);
          expect(story.backdrop.commandGarden.includeEve, isTrue);
          expect(story.backdrop.commandGarden.isGroupVisible, isTrue);
          story.advance();
          expect(story.textIndex, 8); // Show the full group's animation first.
          game.update(3);
          expect(story.backdrop.commandGarden.currentFrame, 5);
        }
        if (line == 9) {
          expect(story.backdrop.isTransitioning, isFalse);
          expect(story.backdrop.commandGarden.currentFrame, 5);
        }
        if (line == 11) {
          final encounter = story.backdrop.encounter;
          expect(
            encounter.field.layers.containsKey(CreationStage.angels),
            isFalse,
          );
          expect(serpentCues, 0);
          expect(story.isNarrationVisible, isFalse);
          expect(encounter.elapsed, 0);
          expect(
            encounter.field.layers.containsKey(CreationStage.people),
            isFalse,
          );
          for (var tap = 0; tap < 5; tap++) {
            story.advance();
          }
          expect(story.dialogue.currentChar, 0);
          game.update(4);
          expect(encounter.forbiddenOpacity, 0);
          expect(encounter.eveProgress, closeTo(0.28, 0.001));
          game.update(1);
          expect(encounter.forbiddenOpacity, 1);
          expect(encounter.forbiddenSnakeVisible, isFalse);
          game.update(1.19);
          expect(encounter.forbiddenSnakeVisible, isFalse);
          expect(serpentCues, 0);
          game.update(0.02);
          expect(encounter.forbiddenSnakeVisible, isTrue);
          expect(serpentCues, 1);
          await capturePreview(tester, game, key, 'genesis-forbidden-snake');
          game.update(3.78);
          expect(encounter.forbiddenOpacity, 1);
          expect(encounter.treeVisible, isFalse);
          game.update(0.01);
          expect(serpentCues, 1);
          expect(encounter.forbiddenOpacity, 1);
          game.update(11 - encounter.elapsed);
          expect(encounter.forbiddenOpacity, 0);
          expect(encounter.forbiddenSnakeVisible, isFalse);
          expect(encounter.treeVisible, isTrue);
          expect(encounter.isWalking, isTrue);
          game.update(2);
          expect(encounter.eveProgress, closeTo(0.39, 0.001));
          expect(story.isNarrationVisible, isFalse);
          expect(story.dialogue.currentChar, 0);
          await capturePreview(tester, game, key, 'genesis-eve-approach');
          game.update(2);
          expect(encounter.hasArrived, isTrue);
          expect(encounter.isWalking, isFalse);
          expect(encounter.eveFrame, 0);
          expect(encounter.eveProgress, closeTo(0.5, 0.001));
          expect(serpentCues, 1);
          expect(story.isNarrationVisible, isTrue);
          expect(story.dialogue.currentChar, 0);
          game.update(0.14);
          expect(story.dialogue.currentChar, greaterThan(0));
          expect(encounter.isSpeaking, isTrue);
          story.advance();
          game.update(1);
          expect(encounter.isSpeaking, isFalse);
          expect(encounter.eveProgress, closeTo(0.5, 0.001));
        }
        for (final size in [
          const Size(960, 540),
          const Size(320, 568),
          const Size(568, 320),
        ]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(
            story.dialogue.y + story.dialogue.height,
            lessThanOrEqualTo(size.height - 40),
          );
          expect(story.backdrop.currentScene, line);
          expect(tester.takeException(), isNull);
          await capturePreview(
            tester,
            game,
            key,
            'garden-story-$line-${size.width.toInt()}',
          );
        }
        if (line == 13) {
          game.update(
            GardenStoryBackdrop.forbiddenReturnHoldDuration -
                GardenStoryBackdrop.treeHoldDuration,
          );
          expect(story.textIndex, 14);
        } else {
          story.advance();
        }
      }
      expect(finishes, 1);
      story.advance();
      expect(finishes, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );
}
