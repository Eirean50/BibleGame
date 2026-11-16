import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// The six poses are not a regular grid. Equal crops align each bird's beak
/// at (460, 210), avoiding position jumps as the wings change pose.
SpriteAnimation birdWingAnimation(ui.Image image) {
  const origins = <Offset>[
    Offset(20, 75),
    Offset(727, 75),
    Offset(1437, 75),
    Offset(81, 619),
    Offset(787, 629),
    Offset(1447, 640),
  ];
  final sx = image.width / 2048;
  final sy = image.height / 1143;
  return SpriteAnimation.spriteList([
    for (final origin in origins)
      Sprite(
        image,
        srcPosition: Vector2(origin.dx * sx, origin.dy * sy),
        srcSize: Vector2(500 * sx, 480 * sy),
      ),
  ], stepTime: 0.14);
}

/// Crosses the sky and wraps only when the entire sprite is off-screen.
class FlyingBird extends SpriteAnimationComponent {
  FlyingBird({
    required SpriteAnimation animation,
    required this.startX,
    required this.altitude,
    required this.speed,
    required this.phase,
    required double width,
  }) : super(
         animation: animation,
         position: Vector2(startX, altitude),
         size: Vector2(width, width * 480 / 500),
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none,
       ) {
    opacity = 0;
    scale.x = speed < 0 ? -1 : 1;
    animationTicker?.update(phase * 0.12);
  }

  final double startX;
  final double altitude;
  final double speed;
  final double phase;
  double _time = 0;

  @override
  void update(double dt) {
    if (opacity <= 0) return;
    super.update(dt);
    _time += dt;
    x = ((startX + 24 + speed * _time) % 368) - 24;
    y = altitude + math.sin(_time * 1.3 + phase) * 3;
    angle = math.sin(_time * 0.8 + phase) * 0.035;
  }
}
