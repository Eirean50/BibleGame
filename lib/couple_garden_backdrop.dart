import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'eden_cliff.dart';
import 'keyed_art.dart';

class CoupleGardenBackdrop extends PositionComponent {
  CoupleGardenBackdrop({bool alreadyTogether = false})
    : _elapsed = alreadyTogether ? animationDuration : 0;
  static const animationDuration = 6.6;
  double _elapsed;
  Sprite? _garden;
  Sprite? _sheet;
  final _frames = <Sprite>[];
  static const _crops = [
    Rect.fromLTWH(120, 110, 465, 660),
    Rect.fromLTWH(630, 110, 400, 660),
    Rect.fromLTWH(1080, 110, 370, 660),
    Rect.fromLTWH(1485, 110, 370, 660),
    Rect.fromLTWH(1895, 110, 350, 660),
    Rect.fromLTWH(2280, 110, 365, 660),
    Rect.fromLTWH(110, 820, 400, 660),
    Rect.fromLTWH(570, 820, 380, 660),
    Rect.fromLTWH(1010, 820, 380, 660),
    Rect.fromLTWH(1430, 820, 380, 660),
    Rect.fromLTWH(1850, 820, 380, 660),
    Rect.fromLTWH(2270, 820, 380, 660),
  ];
  int get currentFrame => math.min((_elapsed / 0.55).floor(), 11);
  bool get isAnimationFinished => _elapsed >= animationDuration;

  @override
  Future<void> onLoad() async {
    _garden = await Sprite.load('garden.png');
    _sheet = await loadKeyedArt('adamandeveakbay.png');
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
    _elapsed = math.min(animationDuration, _elapsed + dt);
  }

  @override
  void render(Canvas canvas) {
    if (_garden == null || _frames.isEmpty || size.x <= 0 || size.y <= 0) {
      return;
    }
    final viewport = size.toSize();
    final fitted = applyBoxFit(
      BoxFit.cover,
      _garden!.srcSize.toSize(),
      viewport,
    );
    canvas.drawImageRect(
      _garden!.image,
      Alignment.center.inscribe(fitted.source, _garden!.src),
      Offset.zero & viewport,
      Paint()..filterQuality = FilterQuality.none,
    );
    final height = math.min(size.y * 0.5, size.x * 0.62);
    final rect = Rect.fromLTWH(
      size.x * 0.5 - height * 0.65,
      size.y * 0.86 - height,
      height * 1.3,
      height,
    );
    drawEdenCliff(canvas, rect);
    _frames[currentFrame].render(
      canvas,
      position: Vector2(size.x * 0.5, rect.bottom),
      size: Vector2(height * _crops[currentFrame].width / 660, height),
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
