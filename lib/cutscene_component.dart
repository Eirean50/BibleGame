import 'package:flame/effects.dart';

import 'creation_backdrop.dart';
import 'narrated_scene.dart';
import 'genesis_audio.dart';

const List<String> creationScript = [
  "In the beginning God created the heavens and the earth.",
  "Now the earth was formless and empty, darkness was over the surface of the deep, and the Spirit of God was hovering over the waters.",
  "And God said, 'Let there be light,' and there was light.",
  "God saw that the light was good, and he separated the light from the darkness. And there was evening, and there was morning—the first day.",
  "And God said, 'Let there be a vault between the waters to separate water from water.' And it was so.",
  "God called the vault 'sky.' And there was evening, and there was morning—the second day.",
  "And God said, 'Let the water under the sky be gathered to one place, and let dry ground appear.' And it was so.",
  "God called the dry ground 'land,' and the gathered waters he called 'seas.' And God saw that it was good.",
  "Then God said, 'Let the land produce vegetation...' And it was so. And there was evening, and there was morning—the third day.",
  "And God said, 'Let there be lights in the vault of the sky to separate the day from the night...' And it was so.",
  "God made two great lights—the greater light to govern the day and the lesser light to govern the night. He also made the stars. And there was evening, and there was morning—the fourth day.",
  "And God said, 'Let the water teem with living creatures, and let birds fly above the earth.' And God saw that it was good. And there was evening, and there was morning—the fifth day.",
  "And God said, 'Let the land produce living creatures according to their kinds...' And it was so.",
  "Then God said, 'Let us make mankind in our image, in our likeness, so that they may rule over the fish in the sea and the birds in the sky, over the livestock and all the wild animals...'",
  "So God created mankind in his own image, in the image of God he created them; male and female he created them.",
];

class CutsceneComponent extends NarratedScene {
  CutsceneComponent({
    required super.onFinished,
    super.onTextIndexChanged,
    GenesisAudio? audio,
  }) : audio = audio ?? GenesisAudio(),
       super(
         script: creationScript,
         heading: 'GENESIS / THE BEGINNING',
         endHint: 'TAP TO ENTER EDEN >',
       );

  final GenesisAudio audio;

  @override
  Future<void> onLoad() async {
    await add(audio);
    await super.onLoad();
  }

  @override
  final CreationBackdrop backdrop = CreationBackdrop();

  /// Zero-based script indices. Replace layers with sprites here as needed.
  @override
  void onTextChanged() {
    audio.creationStep(textIndex);
    switch (textIndex) {
      case 1:
        _fadeIn(CreationStage.waters);
      case 2:
        showLight();
      case 4:
        showSky();
        _fadeIn(CreationStage.angels);
      case 6:
        _fadeIn(CreationStage.land);
      case 8:
        _fadeIn(CreationStage.vegetation);
      case 9:
        _fadeIn(CreationStage.heavens);
      case 11:
        _fadeIn(CreationStage.seaLife);
      case 12:
        _fadeIn(CreationStage.animals);
      case 13:
        _fadeIn(CreationStage.people);
    }
    super.onTextChanged();
  }

  void showLight() => _fadeIn(CreationStage.light);
  void showSky() => _fadeIn(CreationStage.sky);

  void _fadeIn(CreationStage stage) {
    final layer = backdrop.layers[stage]!;
    if (!backdrop.revealed.add(stage)) return;
    layer.add(OpacityEffect.to(1, EffectController(duration: 1.2)));
  }
}
