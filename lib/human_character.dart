import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// One-shot dust-to-Adam sequence, ending on his fully formed pose.
class HumanCreation extends PositionComponent with HasPaint {
  HumanCreation({
    required ui.Image image,
    required Vector2 position,
    bool alreadyFormed = false,
  }) : _playLight = !alreadyFormed,
       super(position: position) {
    for (var i = 0; i < _crops.length; i++) {
      final crop = _crops[i];
      _frames.add(
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
      );
      _sizes.add(Vector2(_widths[i], _widths[i] * crop.height / crop.width));
    }
    opacity = 0;
    _framePaint.filterQuality = FilterQuality.none;
    if (alreadyFormed) _elapsed = formationDuration;
  }

  // Adam remains centered on the same ground baseline throughout the sequence.
  // These are individual stages, not a regularly spaced sprite-sheet grid.
  static const _crops = [
    Rect.fromLTWH(60, 325, 550, 245), // Dust mounds.
    Rect.fromLTWH(1100, 250, 350, 320), // Adam emerging from the dust.
    Rect.fromLTWH(1520, 225, 260, 345), // Clay Adam, kneeling.
    Rect.fromLTWH(75, 750, 270, 335), // Living Adam, still kneeling.
    Rect.fromLTWH(1010, 640, 225, 450), // Standing up.
    adamStandingCrop,
  ];
  static const adamStandingCrop = Rect.fromLTWH(1590, 615, 210, 475);
  // Preserve the original pose heights when narrowing the crops to Adam alone.
  static const _widths = [
    44.0,
    52.0 * 350 / 775,
    40.0 * 260 / 455,
    42.0 * 270 / 530,
    36.0 * 225 / 435,
    34.0 * 210 / 390,
  ];
  static const _stageDuration = 1.6;
  static const _blendDuration = 0.65;
  static const formationDuration = 8.0;
  static const _lightFadeDuration = 1.5;
  final _frames = <Sprite>[];
  final _sizes = <Vector2>[];
  final _framePaint = Paint();
  final bool _playLight;
  double _elapsed = 0;

  bool get isFormed => _elapsed >= formationDuration;
  int get currentStage => math.min((_elapsed / _stageDuration).floor(), 5);
  double get lightIntensity => !_playLight
      ? 0
      : (_elapsed / 0.6).clamp(0.0, 1.0) *
            ((formationDuration + _lightFadeDuration - _elapsed) /
                    _lightFadeDuration)
                .clamp(0.0, 1.0);

  @override
  void update(double dt) {
    super.update(dt);
    if (opacity <= 0) return;
    _elapsed += dt;
    // Breathing begins after formation, with the feet staying anchored.
    scale.y = isFormed
        ? 1 + math.sin((_elapsed - formationDuration) * 1.6) * 0.009
        : 1;
  }

  @override
  void render(Canvas canvas) {
    if (opacity <= 0) return;
    final stage = currentStage;
    final stageTime = _elapsed - stage * _stageDuration;
    final t = isFormed
        ? 0.0
        : ((stageTime - (_stageDuration - _blendDuration)) / _blendDuration)
              .clamp(0.0, 1.0);
    final pulse = math.sin(t * math.pi);
    _drawLight(canvas, pulse);
    // Keep one opaque pose. The warm light peaks as the pose changes, instead
    // of displaying two see-through bodies on top of each other.
    _framePaint.colorFilter = pulse > 0
        ? ColorFilter.mode(
            Color.fromRGBO(255, 231, 158, pulse * 0.65),
            BlendMode.srcATop,
          )
        : null;
    _drawFrame(canvas, stage + (t >= 0.5 ? 1 : 0), opacity);
    _drawSparks(canvas);
  }

  void _drawLight(Canvas canvas, double pulse) {
    final strength = opacity * lightIntensity;
    if (strength <= 0) return;
    final beam = Path()
      ..moveTo(-7, -161)
      ..lineTo(7, -161)
      ..lineTo(32, 1)
      ..lineTo(-32, 1)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -161),
          const Offset(0, 1),
          [
            Color.fromRGBO(255, 248, 210, strength * 0.1),
            Color.fromRGBO(255, 219, 126, strength * 0.26),
            Color.fromRGBO(255, 241, 185, strength * 0.08),
          ],
          [0, 0.75, 1],
        ),
    );
    final aura = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(0, -23),
        48,
        [
          Color.fromRGBO(255, 242, 190, strength * (0.26 + pulse * 0.22)),
          Color.fromRGBO(255, 204, 94, strength * 0.12),
          const Color(0x00FFCC5E),
        ],
        [0, 0.45, 1],
      );
    canvas.drawCircle(const Offset(0, -23), 48, aura);
    canvas.drawOval(
      const Rect.fromLTWH(-30, -5, 60, 10),
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 30, [
          Color.fromRGBO(255, 230, 151, strength * 0.38),
          const Color(0x00FFE697),
        ]),
    );
  }

  void _drawSparks(Canvas canvas) {
    final strength = opacity * lightIntensity;
    if (strength <= 0) return;
    for (var i = 0; i < 10; i++) {
      final progress = (_elapsed * 0.22 + i / 10) % 1;
      final x = math.sin(i * 2.4 + _elapsed * 0.4) * (10 + i % 4 * 4);
      final y = -6 - progress * 100;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 0.8, 1.4),
        Paint()
          ..color = Color.fromRGBO(
            255,
            240,
            180,
            strength * math.sin(progress * math.pi) * 0.85,
          ),
      );
    }
  }

  void _drawFrame(Canvas canvas, int index, double alpha) {
    _framePaint.color = Color.fromRGBO(255, 255, 255, alpha);
    _frames[index].render(
      canvas,
      size: _sizes[index],
      anchor: Anchor.bottomCenter,
      overridePaint: _framePaint,
    );
  }
}
