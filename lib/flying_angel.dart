import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// Front-facing wing cycle plus a small, drift-free flight path.
class FlyingAngel extends SpriteAnimationComponent {
  FlyingAngel({
    required SpriteAnimation animation,
    required Vector2 position,
    required this.phase,
  }) : _home = position.clone(),
       super(
         animation: animation,
         position: position,
         size: Vector2.all(26),
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none,
       ) {
    opacity = 0;
    animationTicker?.update(phase * 0.1);
  }

  final Vector2 _home;
  final double phase;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    position.setValues(
      _home.x + math.sin(_time * 0.55 + phase) * 5,
      _home.y + math.sin(_time * 1.4 + phase) * 2.5,
    );
  }
}
