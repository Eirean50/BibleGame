import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/painting.dart';

List<Sprite> _frames(ui.Image image, List<Rect> crops) => [
  for (final crop in crops)
    Sprite(
      image,
      srcPosition: Vector2(
        crop.left / 2048 * image.width,
        crop.top / 1143 * image.height,
      ),
      srcSize: Vector2(
        crop.width / 2048 * image.width,
        crop.height / 1143 * image.height,
      ),
    ),
];

SpriteAnimation lionAnimation(ui.Image image) =>
    SpriteAnimation.variableSpriteList(
      _frames(image, const [
        Rect.fromLTWH(50, 270, 358, 360),
        Rect.fromLTWH(409, 270, 335, 360),
        Rect.fromLTWH(735, 270, 287, 360),
        Rect.fromLTWH(1025, 270, 282, 360),
        Rect.fromLTWH(1302, 270, 338, 360),
        Rect.fromLTWH(1643, 270, 350, 360),
      ]),
      stepTimes: [1.8, 0.24, 0.25, 0.6, 0.3, 1.8],
    );

SpriteAnimation deerAnimation(ui.Image image) => SpriteAnimation.spriteList(
  // Use the antlered poses only, keeping one consistent animal throughout.
  _frames(image, const [
    Rect.fromLTWH(85, 45, 450, 500),
    Rect.fromLTWH(1040, 45, 450, 500),
    Rect.fromLTWH(1480, 45, 490, 500),
    Rect.fromLTWH(80, 585, 510, 500),
    Rect.fromLTWH(1390, 585, 570, 500),
  ]),
  stepTime: 0.2,
);

/// Keeps each pose's natural proportions and anchors its feet to the ground.
class LandAnimal extends PositionComponent with HasPaint {
  LandAnimal({
    required SpriteAnimation animation,
    required Vector2 position,
    required this.frameHeight,
    this.wanderDistance = 0,
  }) : ticker = animation.createTicker(),
       _homeX = position.x,
       super(position: position) {
    opacity = 0;
    paint.filterQuality = FilterQuality.none;
  }

  final SpriteAnimationTicker ticker;
  final double frameHeight;
  final double wanderDistance;
  final double _homeX;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (opacity <= 0) return;
    _time += dt;
    ticker.update(dt);
    if (wanderDistance > 0) {
      final travel = _time * 0.3;
      x = _homeX + math.sin(travel) * wanderDistance;
      scale.x = math.cos(travel) < 0 ? -1 : 1;
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = ticker.currentFrame.sprite;
    sprite.render(
      canvas,
      size: Vector2(
        frameHeight * sprite.srcSize.x / sprite.srcSize.y,
        frameHeight,
      ),
      anchor: Anchor.bottomCenter,
      overridePaint: paint,
    );
  }
}
