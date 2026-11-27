import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'adam_naming_backdrop.dart';
import 'adam_sleep_backdrop.dart';
import 'couple_garden_backdrop.dart';
import 'garden_backdrop.dart';
import 'forbidden_tree_backdrop.dart';
import 'genesis_audio.dart';
import 'narrated_scene.dart';
import 'serpent_encounter.dart';

const gardenStoryScript = [
  'Out of the ground the LORD God made to grow every tree that is pleasant to the sight and good for food, the tree of life also in the midst of the garden,',
  'and the tree of the knowledge of good and evil,',
  'The man gave names to all cattle, and to the birds of the air, and to every animal of the field; but for the man there was not found a helper as his partner.',
  'So the LORD God caused a deep sleep to fall upon the man, and he slept; then he took one of his ribs and closed up its place with flesh,',
  'And the rib that the LORD God had taken from the man he made into a woman and brought her to the man.',
  'Then the man said, "This at last is bone of my bones and flesh of my flesh; this one shall be called Woman, for out of Man this one was taken."',
  '[2:24] Therefore a man leaves his father and his mother and clings to his wife, and they become one flesh.',
  '[2:25] And the man and his wife were both naked, and were not ashamed.',
  '[2:15] The LORD God took the man and put him in the garden of Eden to till it and keep it.',
  '[2:16] And the LORD God commanded the man, "You may freely eat of every tree of the garden;',
  '[2:17] but of the tree of the knowledge of good and evil you shall not eat, for in the day that you eat of it you shall die."',
  '[3:1] Now the serpent was more crafty than any other wild animal that the LORD God had made. He said to the woman, "Did God say, \'You shall not eat from any tree in the garden\'?"',
  '[3:2] The woman said to the serpent, "We may eat of the fruit of the trees in the garden;',
  '[3:3] but God said, \'You shall not eat of the fruit of the tree that is in the middle of the garden, nor shall you touch it, or you shall die.\'"',
  '[3:4] But the serpent said to the woman, "You will not die;',
  '[3:5] for God knows that when you eat of it your eyes will be opened, and you will be like God, knowing good and evil."',
  '[3:6] So when the woman saw that the tree was good for food, and that it was a delight to the eyes, and that the tree was to be desired to make one wise, she took of its fruit and ate; and she also gave some to her husband, who was with her, and he ate.',
  '[3:7] Then the eyes of both were opened, and they knew that they were naked; and they sewed fig leaves together and made loincloths for themselves.',
  '[3:8] They heard the sound of the LORD God walking in the garden at the time of the evening breeze, and the man and his wife hid themselves from the presence of the LORD God among the trees of the garden.',
  '[3:9] But the LORD God called to the man, and said to him, "Where are you?"',
  '[3:10] He said, "I heard the sound of you in the garden, and I was afraid, because I was naked; and I hid myself."',
  '[3:11] He said, "Who told you that you were naked? Have you eaten from the tree of which I commanded you not to eat?"',
  '[3:12] The man said, "The woman whom you gave to be with me, she gave me fruit from the tree, and I ate."',
  '[3:13] Then the LORD God said to the woman, "What is this that you have done?" The woman said, "The serpent tricked me, and I ate."',
];

class GardenStory extends NarratedScene {
  GardenStory({
    required super.onFinished,
    GenesisAudio? audio,
    List<String> storyScript = gardenStoryScript,
    this.gardenStartIndex = 0,
    bool revealGarden = false,
    this.onSerpentScene,
    this.onAwakening,
  }) : audio = audio ?? GenesisAudio(),
       backdrop = GardenStoryBackdrop(revealGarden: revealGarden),
       super(
         script: storyScript,
         heading: 'GENESIS / THE GARDEN OF EDEN',
         endHint: 'TAP TO CONTINUE >',
         fixedPanelHeight: true,
       );

  final GenesisAudio audio;
  final VoidCallback? onSerpentScene;
  final VoidCallback? onAwakening;
  bool _awakeningMusicStarted = false;
  bool _serpentMusicStarted = false;
  bool _fruitChimePlayed = false;
  bool _footstepsPlayed = false;
  final int gardenStartIndex;
  @override
  final GardenStoryBackdrop backdrop;

  @override
  Future<void> onLoad() async {
    await add(audio);
    await super.onLoad();
  }

  @override
  void onTextChanged() {
    backdrop.showScene(math.max(0, textIndex - gardenStartIndex));
    // The timed tree insert displays Eve's entire warning for its full hold.
    if (backdrop.currentScene == 13) dialogue.skip();
    refreshSceneLayout();
    super.onTextChanged();
  }

  @override
  bool get canAdvance => backdrop.canLeaveScene;

  @override
  bool get canFinish => canAdvance;

  @override
  bool get isNarrationVisible =>
      backdrop.currentScene != 11 || backdrop.encounter.hasArrived;

  @override
  String get waitingHint => switch (backdrop.currentScene) {
    1 || 10 => 'REVEALING THE TREE...',
    13 => 'RETURNING TO THE GARDEN...',
    3 => 'A DEEP SLEEP...',
    4 => 'EVE IS RISING...',
    15 => 'EVE TAKES THE FRUIT...',
    16 => 'THEY EAT THE FRUIT...',
    17 => 'THEIR EYES WERE OPENED...',
    18 => 'THEY HIDE AMONG THE TREES...',
    19 => 'THEY COME OUT FROM HIDING...',
    22 || 23 => 'THEY ANSWER...',
    _ => 'REVEALING THE SCENE...',
  };

  @override
  void updateTree(double dt) {
    final couldAdvance = canAdvance;
    final wasVisible = isNarrationVisible;
    super.updateTree(dt);
    if (!_fruitChimePlayed && backdrop.fruitShineStarted) {
      _fruitChimePlayed = true;
      audio.revealMoment();
    }
    if (backdrop.forbiddenReturnReady) super.advance();
    final confrontation = backdrop.encounter.confrontation;
    if (!_footstepsPlayed && confrontation.footstepsStarted) {
      _footstepsPlayed = true;
      audio.walkingMoment();
    }
    if (backdrop.currentScene == 19 && !isTyping) {
      confrontation.answerCall();
    }
    if (backdrop.currentScene == 23 &&
        dialogue.currentChar >= script[textIndex].indexOf('The woman said')) {
      confrontation.accuseSerpent();
    }
    if (!_awakeningMusicStarted &&
        backdrop.encounter.fruitActors.bothHaveEaten) {
      _awakeningMusicStarted = true;
      onAwakening?.call();
    }
    if (wasVisible != isNarrationVisible) refreshSceneLayout();
    backdrop.encounter.isSpeaking =
        (backdrop.currentScene == 11 ||
            backdrop.currentScene == 14 ||
            backdrop.currentScene == 15) &&
        isTyping;
    if (backdrop.currentScene == 15 && !isTyping) {
      backdrop.encounter.fruitActors.holdFruit();
    }
    if (!_serpentMusicStarted &&
        backdrop.currentScene == 11 &&
        backdrop.encounter.snakeHasAppeared) {
      _serpentMusicStarted = true;
      onSerpentScene?.call();
    }
    final adam = backdrop.sleeping.figures;
    if (backdrop.currentScene == 3 &&
        adam.isAsleep &&
        !adam.hasShone &&
        dialogue.currentChar >= script[textIndex].indexOf('then he took')) {
      adam.shineRib();
      audio.revealMoment();
    }
    if (!couldAdvance && canAdvance) refreshHint();
  }
}

/// Fade the full scenery while keeping narration crisp and tappable.
class GardenStoryBackdrop extends PositionComponent {
  GardenStoryBackdrop({bool revealGarden = false})
    : garden = GardenBackdrop(alreadyRevealed: !revealGarden);

  final GardenBackdrop garden;
  final naming = AdamNamingBackdrop();
  final sleeping = AdamSleepBackdrop();
  final couple = CoupleGardenBackdrop();
  final commandGarden = GardenBackdrop(
    alreadyRevealed: true,
    alreadyAnimated: false,
    includeEve: true,
  );
  final tree = ForbiddenTreeBackdrop();
  final encounter = SerpentEncounter();
  static const transitionDuration = 2.0;
  static const treeHoldDuration = 0.8;
  static const forbiddenReturnHoldDuration = 5.0;
  int _scene = 0;
  int get currentScene => _scene;
  double _elapsed = transitionDuration;
  List<double> _from = [1, 0, 0, 0, 0, 0, 0];
  List<double> _weights = [1, 0, 0, 0, 0, 0, 0];
  bool get isTransitioning => _elapsed < transitionDuration;
  double get _holdDuration => _scene == 13
      ? forbiddenReturnHoldDuration
      : _layerFor(_scene) == 1
      ? treeHoldDuration
      : 0;
  bool get forbiddenReturnReady =>
      _scene == 13 &&
      _elapsed >= transitionDuration + forbiddenReturnHoldDuration;
  bool get fruitShineStarted => _scene == 13 && _elapsed >= transitionDuration;
  bool get canLeaveScene =>
      _elapsed >= transitionDuration + _holdDuration &&
      switch (_scene) {
        3 => sleeping.figures.shineFinished,
        4 => sleeping.figures.eveFinished,
        5 => couple.isAnimationFinished,
        8 => commandGarden.isAnimationFinished,
        11 => encounter.hasArrived,
        15 => encounter.fruitActors.holdingFinished,
        16 => encounter.fruitActors.eatingFinished,
        17 => encounter.fruitActors.awarenessFinished,
        >= 18 => encounter.confrontation.canLeaveScene,
        _ => true,
      };
  double get treeOpacity => _weights[1];
  int _layerFor(int scene) => switch (scene) {
    <= 3 => scene,
    4 => 3,
    5 || 6 || 7 => 4,
    8 || 9 => 5,
    10 || 13 => 1,
    11 || 12 || >= 14 => 6,
    _ => throw ArgumentError.value(scene, 'scene'),
  };

  @override
  Future<void> onLoad() async {
    await addAll([
      garden,
      tree,
      naming,
      sleeping,
      couple,
      commandGarden,
      encounter,
    ]);
  }

  void showScene(int index) {
    if (index == _scene) return;
    final sameLayer = _layerFor(index) == _layerFor(_scene);
    _from = List.of(_weights);
    _scene = index;
    _elapsed = sameLayer ? transitionDuration : 0;
    if (index == 4) sleeping.figures.revealEve();
    if (index == 16) encounter.fruitActors.beginEating();
    if (index == 17) encounter.fruitActors.beginAwareness();
    if (index >= 18) encounter.confrontation.showScene(index);
  }

  @override
  void updateTree(double dt) {
    update(dt);
    garden.updateTree(dt);
    if (_scene == 2) naming.updateTree(dt);
    if (_scene == 3 || _scene == 4) sleeping.updateTree(dt);
    if (_scene >= 5 && _scene <= 7) couple.updateTree(dt);
    if (_scene == 8 || _scene == 9) commandGarden.updateTree(dt);
    if (_scene == 11 || _scene == 12 || _scene >= 14) encounter.updateTree(dt);
  }

  @override
  void update(double dt) {
    garden.size.setFrom(size);
    naming.size.setFrom(size);
    sleeping.size.setFrom(size);
    couple.size.setFrom(size);
    commandGarden.size.setFrom(size);
    tree.size.setFrom(size);
    encounter.size.setFrom(size);
    // Only visible scenes advance, so Adam begins when the naming line appears.
    _elapsed = math.min(transitionDuration + _holdDuration, _elapsed + dt);
    final shineTime = math.max(0.0, _elapsed - transitionDuration);
    tree.shineIntensity = _scene == 13
        ? math.min(1.0, shineTime / 0.4) *
              (0.65 + 0.35 * math.sin(shineTime * 4))
        : 0;
    final t = (_elapsed / transitionDuration).clamp(0.0, 1.0);
    final eased = t * t * (3 - 2 * t);
    _weights = List.generate(
      _from.length,
      (i) => _from[i] * (1 - eased) + (i == _layerFor(_scene) ? eased : 0),
    );
  }

  @override
  void renderTree(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    garden.size.setFrom(size);
    naming.size.setFrom(size);
    sleeping.size.setFrom(size);
    couple.size.setFrom(size);
    commandGarden.size.setFrom(size);
    tree.size.setFrom(size);
    encounter.size.setFrom(size);
    final viewport = Offset.zero & size.toSize();
    canvas.save();
    canvas.clipRect(viewport);
    // Add weighted premultiplied layers for a true crossfade without a dark dip.
    canvas.saveLayer(viewport, Paint());
    for (var i = 0; i < _weights.length; i++) {
      if (_weights[i] <= 0) continue;
      canvas.saveLayer(
        viewport,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, _weights[i])
          ..blendMode = BlendMode.plus,
      );
      if (i == 0) {
        garden.renderTree(canvas);
      } else if (i == 1) {
        tree.renderTree(canvas);
      } else if (i == 2) {
        naming.renderTree(canvas);
      } else if (i == 3) {
        sleeping.renderTree(canvas);
      } else if (i == 4) {
        couple.renderTree(canvas);
      } else if (i == 5) {
        commandGarden.renderTree(canvas);
      } else if (i == 6) {
        encounter.renderTree(canvas);
      }
      canvas.restore();
    }
    canvas.restore();
    canvas.restore();
  }
}
