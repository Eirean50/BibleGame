import 'package:flame/components.dart';

import 'garden_story.dart';
import 'genesis_audio.dart';
import 'serpent_encounter.dart';

export 'garden_backdrop.dart';

const List<String> edenScript = [
  'By the seventh day, the heavens and the earth were fully completed.',
  'God rested from all the work He had done, blessing the seventh day and making it holy.',
  'The Creator planted a beautiful garden in the east, in Eden.',
  ...gardenStoryScript,
];

class EdenCutscene extends GardenStory {
  EdenCutscene({
    required super.onFinished,
    super.audio,
    super.onSerpentScene,
    super.onAwakening,
  }) : super(storyScript: edenScript, gardenStartIndex: 3, revealGarden: true);

  @override
  bool get canAdvance =>
      (textIndex < 2 ||
          (backdrop.garden.isRevealed &&
              backdrop.garden.isAnimationFinished)) &&
      super.canAdvance;

  @override
  String get waitingHint =>
      textIndex <= 3 ? 'REVEALING THE GARDEN...' : super.waitingHint;
}

/// Hold the confrontation after Eve's answer in Genesis 3:13.
class GardenEnding extends PositionComponent {
  GardenEnding({GenesisAudio? audio}) : audio = audio ?? GenesisAudio();

  final GenesisAudio audio;
  final backdrop = SerpentEncounter(alreadyArrived: true, storyComplete: true);

  @override
  Future<void> onLoad() async => addAll([backdrop, audio]);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
    backdrop.size.setFrom(size);
  }
}
