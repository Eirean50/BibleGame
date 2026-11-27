import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'keyed_art.dart';

enum FruitAction { none, holding, eating, awareness }

/// One-shot poses from the user's aadameveforb sheet.
class ForbiddenFruitActors extends PositionComponent {
  ForbiddenFruitActors({bool completed = false, required this.characterPaint})
      : action = completed ? FruitAction.awareness : FruitAction.none,
        _elapsed = completed ? 3 : 0;
  FruitAction action;
  final Paint characterPaint;
  double _elapsed;
  static const eatingDuration = 10.0;
  bool get hasFruit => action != FruitAction.none;
  bool get holdingFinished => action == FruitAction.holding && _elapsed >= 1.2;
  bool get eatingFinished => action == FruitAction.eating && _elapsed >= eatingDuration;
  bool get awarenessFinished => action == FruitAction.awareness && _elapsed >= 3;
  int get eatingStage => math.min((_elapsed / 2).floor(), 4);
  Sprite? _sheet;
  final _poses = <Sprite>[];
  static const crops = [
    Rect.fromLTWH(175, 110, 245, 660), // Adam waiting.
    Rect.fromLTWH(425, 150, 245, 620), // Eve holding fruit.
    Rect.fromLTWH(760, 150, 240, 620), // Eve bites.
    Rect.fromLTWH(1070, 150, 250, 620), // Eve chews, empty hand.
    Rect.fromLTWH(1970, 110, 640, 660), // Eve hands fruit to Adam.
    Rect.fromLTWH(1460, 110, 400, 660), // Adam receives.
    Rect.fromLTWH(1090, 900, 230, 600), // Adam bites.
  ];
  void holdFruit() {
    if (action != FruitAction.none) return;
    action = FruitAction.holding;
    _elapsed = 0;
  }
  void beginEating() { action = FruitAction.eating; _elapsed = 0; }
  void beginAwareness() { action = FruitAction.awareness; _elapsed = 0; }

  @override
  Future<void> onLoad() async {
    _sheet = await loadKeyedArt('aadameveforb.png');
    final image = _sheet!.image;
    for (final crop in crops) {
      _poses.add(Sprite(image,
        srcPosition: Vector2(crop.left / 2752 * image.width, crop.top / 1536 * image.height),
        srcSize: Vector2(crop.width / 2752 * image.width, crop.height / 1536 * image.height)));
    }
  }
  @override
  void update(double dt) {
    if (hasFruit) _elapsed += math.max(0, dt);
  }
  @override
  void render(Canvas canvas) {
    if (!hasFruit || _poses.isEmpty) return;
    final eveHeight = math.min(size.y * 0.34, size.x * 0.27);
    final adamHeight = eveHeight * 1.1;
    final ground = size.y * 0.91;
    void pose(int index, double x, double height, {bool flip = false}) {
      canvas.save();
      canvas.translate(size.x * x, ground);
      if (flip) canvas.scale(-1, 1);
      _poses[index].render(canvas, anchor: Anchor.bottomCenter,
        size: Vector2(height * crops[index].width / crops[index].height, height),
        overridePaint: characterPaint);
      canvas.restore();
    }
    if (action == FruitAction.holding) {
      pose(1, 0.5, eveHeight, flip: true);
      return;
    }
    if (action == FruitAction.eating && eatingStage == 2) {
      pose(4, 0.45, adamHeight);
      return;
    }
    final arriving = action == FruitAction.eating ? (_elapsed / 2).clamp(0.0, 1.0) : 1.0;
    final adamX = 0.16 + 0.23 * arriving;
    if (action == FruitAction.awareness) {
      pose(0, adamX, adamHeight);
      pose(3, 0.5, eveHeight);
      // Fig leaves gather at their waists, then settle into their loincloths.
      final progress = (_elapsed / 3).clamp(0.0, 1.0);
      for (final x in [adamX, 0.5]) {
        for (var i = 0; i < 3; i++) {
          final center = Offset(size.x * x + (i - 1) * eveHeight * 0.075,
              ground - eveHeight * (0.38 + (1 - progress) * 0.15));
          final leaf = Rect.fromCenter(center: center,
              width: eveHeight * 0.09, height: eveHeight * 0.14);
          canvas.drawOval(leaf, Paint()..color = const Color(0xFF537B32).withValues(alpha: progress));
          canvas.drawLine(leaf.topCenter, leaf.bottomCenter,
              Paint()..color = const Color(0xFFADC66A).withValues(alpha: progress)..strokeWidth = 1);
        }
      }
      return;
    }
    pose(eatingStage >= 4 ? 6 : eatingStage == 3 ? 5 : 0, adamX, adamHeight);
    pose(eatingStage == 0 ? 1 : eatingStage == 1 ? 2 : 3, 0.5, eveHeight);
  }
  @override
  void onRemove() {
    _sheet?.image.dispose();
    _sheet = null;
    _poses.clear();
    super.onRemove();
  }
}
