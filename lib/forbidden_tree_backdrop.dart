import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// The supplied tree artwork, shared by both mentions and the final hold.
class ForbiddenTreeBackdrop extends PositionComponent {
  Sprite? _tree;
  double shineIntensity = 0;

  @override
  Future<void> onLoad() async => _tree = await Sprite.load('forbidden.png');

  @override
  void render(Canvas canvas) {
    final tree = _tree;
    if (tree == null || size.x <= 0 || size.y <= 0) return;
    final viewport = size.toSize();
    final fitted = applyBoxFit(BoxFit.cover, tree.srcSize.toSize(), viewport);
    canvas.drawImageRect(
      tree.image,
      Alignment.center.inscribe(fitted.source, tree.src),
      Offset.zero & viewport,
      Paint()..filterQuality = FilterQuality.none,
    );
    if (shineIntensity > 0) {
      final source = Alignment.center.inscribe(fitted.source, tree.src);
      final center = Offset(
        (tree.image.width * 1750 / 2752 - source.left) / source.width * size.x,
        (tree.image.height * 570 / 1536 - source.top) / source.height * size.y);
      final radius = size.x / source.width * tree.image.width * 110 / 2752;
      canvas.drawCircle(center, radius, Paint()..shader = ui.Gradient.radial(
        center, radius, [Color.fromRGBO(255, 251, 202, shineIntensity),
          Color.fromRGBO(255, 199, 64, shineIntensity * 0.7), const Color(0x00FFC740)],
        [0, 0.35, 1]));
      final rays = Paint()..color = Color.fromRGBO(255, 255, 220, shineIntensity)
        ..strokeWidth = math.max(1, radius * 0.06);
      for (var i = 0; i < 4; i++) {
        final angle = i * math.pi / 4;
        final offset = Offset(math.cos(angle), math.sin(angle)) * radius * 0.8;
        canvas.drawLine(center - offset, center + offset, rays);
      }
    }
  }
}
