import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'eden_cutscene.dart';

/// Level entry scene. Add the player, map and gameplay systems here.
class Level1 extends PositionComponent {
  final backdrop = GardenBackdrop(alreadyRevealed: true);
  final _title = TextComponent(
    text: 'LEVEL 1',
    anchor: Anchor.topCenter,
    textRenderer: TextPaint(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 24,
        color: Color(0xFFFFE6B7),
      ),
    ),
  );

  @override
  Future<void> onLoad() async {
    await addAll([backdrop, _title]);
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
    _layout();
  }

  void _layout() {
    backdrop.size.setFrom(size);
    _title.position.setValues(size.x / 2, 24);
  }
}
