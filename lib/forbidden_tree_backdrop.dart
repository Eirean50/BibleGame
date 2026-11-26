import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

/// The supplied tree artwork, shared by both mentions and the final hold.
class ForbiddenTreeBackdrop extends PositionComponent {
  Sprite? _tree;

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
  }
}
