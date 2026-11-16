import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;

import 'cutscene_component.dart';
import 'level1.dart';
import 'keyed_art.dart';
import 'eden_cutscene.dart';
import 'war_cutscene.dart';

class OldTestamentGame extends FlameGame with HasKeyboardHandlerComponents {
  // The normal opening uses only the fullscreen movie.
  OldTestamentGame({this.playWarVideo = true});

  final bool playWarVideo;
  static const warVideoOverlay = 'warVideo';
  late final RouterComponent router;
  late final CutsceneComponent cutscene;
  late final EdenCutscene eden;
  late final WarCutscene war;
  late final Level1 kingdom;

  @override
  Color backgroundColor() => const Color(0xFF090E20);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Keep GameWidget's loading indicator visible until images are ready.
    // All later scenes reuse these decoded assets; no pixel cleanup at runtime.
    await images.loadAll([
      'bg_sky.png',
      'bg_sea.png',
      'AngelsSpriteSheetNew.png',
      'garden.png',
      'kingdom.png',
      'prepared/angel_avatar.png',
      'prepared/devil.png',
      if (!playWarVideo) 'prepared/warangels.png',
      'prepared/jesuswithadamandeve.png',
      for (final name in preparedArtNames) 'prepared/$name',
    ]);
    router = RouterComponent(
      initialRoute: 'war',
      routes: {
        'war': Route(
          () => war = WarCutscene(
            videoControlled: playWarVideo,
            onStarted: playWarVideo
                ? () => overlays.add(warVideoOverlay)
                : null,
            onFinished: () {
              overlays.remove(warVideoOverlay);
              router.pushReplacementNamed('Level1');
            },
          ),
          maintainState: false,
        ),
        'intro': Route(() {
          return cutscene = CutsceneComponent(
            onFinished: () => router.pushReplacementNamed('eden'),
          );
        }, maintainState: false),
        'eden': Route(
          () => eden = EdenCutscene(
            onFinished: () => router.pushReplacementNamed('ending'),
          ),
          maintainState: false,
        ),
        'Level1': Route(
          () => kingdom = Level1(
            onContinue: () => router.pushReplacementNamed('intro'),
          ),
          maintainState: false,
        ),
        'ending': Route(GardenEnding.new, maintainState: false),
      },
    );
    await add(router);
  }

  @override
  void onRemove() {
    // GameWidget detaches the game without removing each child component.
    for (final level in descendants().whereType<Level1>()) {
      level.disposeAudio();
    }
    super.onRemove();
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      for (final level in descendants().whereType<Level1>()) {
        level.stopMovement();
      }
    }
    super.lifecycleStateChange(state);
  }
}
