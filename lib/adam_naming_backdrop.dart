import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'creation_backdrop.dart';
import 'keyed_art.dart';

/// The completed Creation landscape, with birds, angels, and Adam's sheep.
class AdamNamingBackdrop extends CreationBackdrop {
  AdamNamingBackdrop({bool alreadyPetting = false})
    : adam = AdamPettingSheep(alreadyPetting: alreadyPetting),
      super(
        stages: CreationStage.values.where(
          (stage) =>
              stage != CreationStage.animals && stage != CreationStage.people,
        ),
        showFish: false,
      );

  final AdamPettingSheep adam;

  @override
  void renderTree(Canvas canvas) {
    // The scenery fills the viewport; keep Adam and the sheep proportional
    // even when the landscape is stretched for a portrait screen.
    if (size.x <= 0 || size.y <= 0) return;
    adam.scale.x = (size.y / 180) / (size.x / 320);
    super.renderTree(canvas);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final layer in layers.values) {
      layer.opacity = 1;
    }
    revealed.addAll(layers.keys);
    await add(adam);
  }
}

class AdamPettingSheep extends PositionComponent {
  AdamPettingSheep({bool alreadyPetting = false})
    : _elapsed = alreadyPetting ? 1.65 : 0,
      super(position: Vector2(160, 162), priority: 5);

  Sprite? _sheet;
  final _frames = <Sprite>[];
  double _elapsed;
  // Hand-fitted poses in the supplied 2752x1536 sheet. All share a baseline.
  static const _crops = [
    Rect.fromLTRB(110, 110, 580, 770),
    Rect.fromLTRB(600, 110, 1055, 770),
    Rect.fromLTRB(1055, 110, 1465, 770),
    Rect.fromLTRB(1490, 110, 1865, 770),
    Rect.fromLTRB(1870, 110, 2245, 770),
    Rect.fromLTRB(2250, 110, 2690, 770),
    Rect.fromLTRB(120, 770, 550, 1430),
    Rect.fromLTRB(570, 770, 980, 1430),
    Rect.fromLTRB(1010, 770, 1390, 1430),
    Rect.fromLTRB(1420, 770, 1795, 1430),
    Rect.fromLTRB(1830, 770, 2240, 1430),
  ];
  static const _pettingCycle = [3, 4, 5, 6, 7, 8, 9, 10, 9, 8, 7, 6];
  int get currentFrame {
    final step = (_elapsed / 0.55).floor();
    return step < 3 ? step : _pettingCycle[(step - 3) % _pettingCycle.length];
  }

  @override
  Future<void> onLoad() async {
    _sheet = await loadKeyedArt('adampettingsheep.png');
    final image = _sheet!.image;
    for (final crop in _crops) {
      _frames.add(
        Sprite(
          image,
          srcPosition: Vector2(
            crop.left / 2752 * image.width,
            crop.top / 1536 * image.height,
          ),
          srcSize: Vector2(
            crop.width / 2752 * image.width,
            crop.height / 1536 * image.height,
          ),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += math.max(0, dt);
  }

  @override
  void render(Canvas canvas) {
    if (_frames.isEmpty) return;
    final frame = currentFrame;
    _frames[frame].render(
      canvas,
      size: Vector2(72 * _crops[frame].width / 660, 72),
      anchor: Anchor.bottomCenter,
      overridePaint: Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  void onRemove() {
    _sheet?.image.dispose();
    _sheet = null;
    _frames.clear();
    super.onRemove();
  }
}
