import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/cutscene_component.dart';
import 'package:itlective/eden_cutscene.dart';
import 'package:itlective/genesis_audio.dart';
import 'package:itlective/old_testament_game.dart';
import 'package:itlective/sword_sound.dart';

class _Sound extends SwordSound {
  int plays = 0;
  int stops = 0;
  int disposals = 0;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposals++;
}

class _Sounds {
  final waters = _Sound();
  final wind = _Sound();
  final nature = _Sound();
  final reveal = _Sound();
  List<_Sound> get all => [waters, wind, nature, reveal];
  GenesisAudio audio({GenesisAmbience initial = GenesisAmbience.waters}) =>
      GenesisAudio(
        initialAmbience: initial,
        waters: waters,
        wind: wind,
        nature: nature,
        reveal: reveal,
      );
}

// Keep the real application's audio lifecycle, without playing its war intro.
class _GenesisGame extends OldTestamentGame {
  _GenesisGame(this.scene);
  final Component scene;
  @override
  Future<void> onLoad() async => add(scene);
}

Future<void> _mountScene(WidgetTester tester, _GenesisGame game) async {
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.runAsync(() async {
    for (var i = 0; i < 500 && !game.scene.isMounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  expect(game.scene.isMounted, isTrue);
  game.pauseEngine();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Creation cues follow dialogue and resume only the current ambience',
    (tester) async {
      final sounds = _Sounds();
      var completed = 0;
      final audio = sounds.audio();
      final scene = CutsceneComponent(
        audio: audio,
        onFinished: () => completed++,
      );
      final game = _GenesisGame(scene);
      await _mountScene(tester, game);
      expect(sounds.waters.plays, 1);
      audio.resumeAudio();
      expect(sounds.waters.plays, 1);
      void advanceTo(int index) {
        while (scene.textIndex < index) {
          if (scene.isTyping) scene.advance();
          scene.advance();
        }
      }

      advanceTo(2);
      expect(sounds.reveal.plays, 1);
      scene.advance(); // Reveal text, not another sound cue.
      expect(sounds.reveal.plays, 1);
      advanceTo(4);
      expect(sounds.waters.stops, 1);
      expect(sounds.wind.plays, 1);
      advanceTo(6);
      expect(sounds.reveal.plays, 2);
      advanceTo(9);
      expect(sounds.reveal.plays, 3);
      expect(sounds.nature.plays, 0);
      advanceTo(11);
      expect(sounds.wind.stops, 1);
      expect(sounds.nature.plays, 1);
      advanceTo(13);
      expect(sounds.reveal.plays, 4);
      game.lifecycleStateChange(AppLifecycleState.paused);
      expect(sounds.all.every((sound) => sound.stops > 0), isTrue);
      game.lifecycleStateChange(AppLifecycleState.resumed);
      game.pauseEngine();
      expect(sounds.nature.plays, 2);
      expect(sounds.waters.plays, 1);
      expect(sounds.wind.plays, 1);
      expect(sounds.reveal.plays, 4);
      advanceTo(14);
      if (scene.isTyping) scene.advance();
      scene.advance();
      scene.advance();
      expect(completed, 1);
      scene.removeFromParent();
      game.update(0);
      await tester.pump();
      expect(sounds.all.every((sound) => sound.disposals == 1), isTrue);
      audio.resumeAudio();
      audio.creationStep(2);
      expect(sounds.reveal.plays, 4);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );

  for (final ending in [false, true]) {
    testWidgets(
      '${ending ? 'Garden ending' : 'Eden'} has nature audio and cleans up on exit',
      (tester) async {
        final sounds = _Sounds();
        final audio = sounds.audio(initial: GenesisAmbience.nature);
        final scene = ending
            ? GardenEnding(audio: audio)
            : EdenCutscene(audio: audio, onFinished: () {});
        final game = _GenesisGame(scene);
        await _mountScene(tester, game);
        expect(sounds.nature.plays, 1);
        expect(sounds.waters.plays, 0);
        expect(sounds.reveal.plays, 0);
        game.lifecycleStateChange(AppLifecycleState.inactive);
        expect(sounds.nature.stops, 1);
        game.lifecycleStateChange(AppLifecycleState.resumed);
        game.pauseEngine();
        expect(sounds.nature.plays, 2);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
        expect(sounds.all.every((sound) => sound.disposals == 1), isTrue);
        audio.resumeAudio();
        expect(sounds.nature.plays, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('All Genesis sounds are bundled PCM without clipping', () async {
    for (final name in GenesisAudio.assets) {
      final data = await rootBundle.load('assets/$name');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(data.getUint32(24, Endian.little), 44100);
      expect(data.getUint32(40, Endian.little), data.lengthInBytes - 44);
      var peak = 0;
      for (var i = 44; i < data.lengthInBytes; i += 2) {
        final value = data.getInt16(i, Endian.little).abs();
        if (value > peak) peak = value;
      }
      expect(peak, inExclusiveRange(1000, 32767));
      if (name != GenesisAudio.revealAsset) {
        final start = data.getInt16(44, Endian.little);
        final end = data.getInt16(data.lengthInBytes - 2, Endian.little);
        expect((start - end).abs(), lessThan(1700), reason: '$name loop seam');
      }
    }
  });
}
