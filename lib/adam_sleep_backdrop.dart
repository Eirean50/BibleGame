import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'creation_backdrop.dart';
import 'keyed_art.dart';

class AdamSleepBackdrop extends CreationBackdrop {
  AdamSleepBackdrop()
    : super(
        stages: CreationStage.values.where(
          (s) => s != CreationStage.animals && s != CreationStage.people,
        ),
        showFish: false,
      );

  final figures = SleepingAdam();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final layer in layers.values) {
      layer.opacity = 1;
    }
    await add(figures);
  }

  @override
  void renderTree(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    figures.scale.x = (size.y / 180) / (size.x / 320);
    super.renderTree(canvas);
  }
}

class SleepingAdam extends PositionComponent {
  SleepingAdam() : super(position: Vector2(128, 162), priority: 5);

  Sprite? _sleepSheet;
  Sprite? _humanSheet;
  final _sleepFrames = <Sprite>[];
  final _eveFrames = <Sprite>[];
  double _sleepTime = 0;
  double? _shineTime;
  double? _eveTime;
  static const sleepDuration = 4.5;
  static const shineDuration = 3.2;
  static const eveDuration = 5.5;
  static const _sleepCrops = [
    Rect.fromLTWH(180, 110, 250, 660),
    Rect.fromLTWH(610, 110, 280, 660),
    Rect.fromLTWH(1040, 110, 340, 660),
    Rect.fromLTWH(1440, 110, 345, 660),
    Rect.fromLTWH(1840, 110, 395, 660),
    Rect.fromLTWH(2300, 110, 350, 660),
    Rect.fromLTWH(65, 770, 450, 660),
    Rect.fromLTWH(505, 770, 440, 660),
    Rect.fromLTWH(980, 770, 415, 660),
    Rect.fromLTWH(1395, 770, 430, 660),
  ];
  static const _eveCrops = [
    Rect.fromLTWH(1790, 225, 180, 345),
    Rect.fromLTWH(375, 750, 225, 335),
    Rect.fromLTWH(1270, 640, 175, 450),
    Rect.fromLTWH(1820, 615, 160, 475),
  ];
  bool get isAsleep => _sleepTime >= sleepDuration;
  bool get hasShone => _shineTime != null;
  bool get shineFinished => (_shineTime ?? -1) >= shineDuration;
  bool get eveFinished => (_eveTime ?? -1) >= eveDuration;
  bool get isEveVisible => _eveTime != null;
  double get shineIntensity {
    final t = _shineTime;
    if (t == null || t >= shineDuration) return 0;
    return math.sin(math.pi * t / shineDuration);
  }

  void shineRib() => _shineTime ??= 0;
  void revealEve() => _eveTime ??= 0;

  Sprite _crop(ui.Image image, Rect crop, double width, double height) =>
      Sprite(
        image,
        srcPosition: Vector2(
          crop.left / width * image.width,
          crop.top / height * image.height,
        ),
        srcSize: Vector2(
          crop.width / width * image.width,
          crop.height / height * image.height,
        ),
      );

  @override
  Future<void> onLoad() async {
    _sleepSheet = await loadKeyedArt('sleepingadam.png');
    _humanSheet = await loadKeyedArt('human.png');
    for (final crop in _sleepCrops) {
      _sleepFrames.add(_crop(_sleepSheet!.image, crop, 2752, 1536));
    }
    for (final crop in _eveCrops) {
      _eveFrames.add(_crop(_humanSheet!.image, crop, 2048, 1143));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sleepTime += dt;
    if (_shineTime != null) _shineTime = _shineTime! + dt;
    if (_eveTime != null) _eveTime = _eveTime! + dt;
  }

  @override
  void render(Canvas canvas) {
    if (_sleepFrames.isEmpty) return;
    final frame = math.min((_sleepTime / 0.45).floor(), 9);
    final crop = _sleepCrops[frame];
    _sleepFrames[frame].render(
      canvas,
      size: Vector2(crop.width * 0.15, crop.height * 0.15),
      anchor: Anchor.bottomCenter,
      overridePaint: Paint()..filterQuality = FilterQuality.none,
    );
    final glow = shineIntensity;
    if (glow > 0) {
      const rib = Offset(2, -28);
      canvas.drawCircle(
        rib,
        31,
        Paint()
          ..shader = ui.Gradient.radial(
            rib,
            31,
            [
              Color.fromRGBO(255, 255, 225, glow),
              Color.fromRGBO(255, 218, 109, glow * 0.65),
              const Color(0x00FFDA6D),
            ],
            [0, 0.2, 1],
          ),
      );
      for (var i = 0; i < 10; i++) {
        final angle = i * math.pi / 5 + _shineTime! * 0.2;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          rib + direction * 5,
          rib + direction * (12 + glow * 14),
          Paint()
            ..color = Color.fromRGBO(255, 245, 189, glow)
            ..strokeWidth = 0.8,
        );
      }
    }
    if (_eveTime != null) _drawEve(canvas, _eveTime!);
  }

  void _drawEve(Canvas canvas, double time) {
    const center = Offset(76, 0);
    final progress = (time / eveDuration).clamp(0.0, 1.0);
    final dust = (1 - progress).clamp(0.0, 1.0);
    final mound = Path()
      ..moveTo(54, 0)
      ..quadraticBezierTo(62, -14, 76, -9)
      ..quadraticBezierTo(89, -13, 99, 0)
      ..close();
    canvas.drawPath(mound, Paint()..color = Color.fromRGBO(184, 137, 79, dust));
    final frame = time < 1.7
        ? 0
        : time < 3
        ? 1
        : time < 4.3
        ? 2
        : 3;
    final crop = _eveCrops[frame];
    final alpha = ((time - 0.4) / 0.7).clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(48, -80 * (time / 1.7).clamp(0.0, 1.0), 104, 1),
    );
    _eveFrames[frame].render(
      canvas,
      position: Vector2(center.dx, center.dy),
      size: Vector2(crop.width * 0.17, crop.height * 0.17),
      anchor: Anchor.bottomCenter,
      overridePaint: Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    canvas.restore();
    for (var i = 0; i < 30; i++) {
      final phase = (time * 0.35 + i / 30) % 1;
      final x = center.dx + math.sin(i * 2.4 + time) * (10 + phase * 14);
      final y = -phase * (25 + progress * 50);
      canvas.drawRect(
        Rect.fromLTWH(x, y, 1.4, 1.4),
        Paint()
          ..color = Color.fromRGBO(
            244,
            206,
            133,
            dust * math.sin(phase * math.pi),
          ),
      );
    }
  }

  @override
  void onRemove() {
    _sleepSheet?.image.dispose();
    _humanSheet?.image.dispose();
    _sleepSheet = _humanSheet = null;
    _sleepFrames.clear();
    _eveFrames.clear();
    super.onRemove();
  }
}
