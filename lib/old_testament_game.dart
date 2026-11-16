import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Route;

import 'cutscene_component.dart';
import 'level1.dart';
import 'keyed_art.dart';
import 'eden_cutscene.dart';

class OldTestamentGame extends FlameGame {
  late final RouterComponent router;
  late final CutsceneComponent cutscene;
  late final EdenCutscene eden;

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
      'prepared/jesuswithadamandeve.png',
      for (final name in preparedArtNames) 'prepared/$name',
    ]);
    router = RouterComponent(
      initialRoute: 'intro',
      routes: {
        'intro': Route(() {
          return cutscene = CutsceneComponent(
            onFinished: () => router.pushReplacementNamed('eden'),
          );
        }, maintainState: false),
        'eden': Route(
          () => eden = EdenCutscene(
            onFinished: () => router.pushReplacementNamed('Level1'),
          ),
          maintainState: false,
        ),
        'Level1': Route(Level1.new),
      },
    );
    await add(router);
  }
}
