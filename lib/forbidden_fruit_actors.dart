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
  static const biteCompletedAt = 10.0;
  static const eatingDuration = 12.0;
  bool get bothHaveEaten =>
      action == FruitAction.awareness ||
      (action == FruitAction.eating && _elapsed >= biteCompletedAt);
  bool get adamIsWalking => action == FruitAction.eating && _elapsed < 2;
  int get adamWalkFrame => (_elapsed * 8).floor() % 6;
  bool get hasFruit => action != FruitAction.none;
  bool get holdingFinished => action == FruitAction.holding && _elapsed >= 1.2;
  bool get eatingFinished =>
      action == FruitAction.eating && _elapsed >= eatingDuration;
  bool get awarenessFinished =>
      action == FruitAction.awareness && _elapsed >= 3;
  int get eatingStage => math.min((_elapsed / 2).floor(), 4);
  Sprite? _sheet;
  Sprite? _walkingSheet;
  Sprite? _reactionSheet;
  final _walk = <Sprite>[];
  final _reactions = <Sprite>[];
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
  static const walkCrops = [
    Rect.fromLTWH(175, 120, 245, 640),
    Rect.fromLTWH(600, 145, 320, 615),
    Rect.fromLTWH(1075, 140, 220, 620),
    Rect.fromLTWH(1470, 125, 300, 635),
    Rect.fromLTWH(1875, 145, 335, 615),
    Rect.fromLTWH(2335, 140, 240, 620),
  ];
  Sprite _crop(Sprite sheet, Rect crop) => Sprite(
    sheet.image,
    srcPosition: Vector2(
      crop.left / 2752 * sheet.image.width,
      crop.top / 1536 * sheet.image.height,
    ),
    srcSize: Vector2(
      crop.width / 2752 * sheet.image.width,
      crop.height / 1536 * sheet.image.height,
    ),
  );
  void holdFruit() {
    if (action != FruitAction.none) return;
    action = FruitAction.holding;
    _elapsed = 0;
  }

  void beginEating() {
    action = FruitAction.eating;
    _elapsed = 0;
  }

  void beginAwareness() {
    action = FruitAction.awareness;
    _elapsed = 0;
  }

  @override
  Future<void> onLoad() async {
    _sheet = await loadKeyedArt('aadameveforb.png');
    _walkingSheet = await loadKeyedArt('adamwalking-solid.png');
    _reactionSheet = await loadKeyedArt('evetalking-solid.png');
    for (final crop in walkCrops) {
      _walk.add(_crop(_walkingSheet!, crop));
    }
    _reactions.addAll([
      _crop(_walkingSheet!, const Rect.fromLTWH(1900, 910, 310, 585)),
      _crop(_reactionSheet!, const Rect.fromLTWH(165, 920, 290, 580)),
      _crop(_reactionSheet!, const Rect.fromLTWH(615, 920, 245, 580)),
    ]);
    final image = _sheet!.image;
    for (final crop in crops) {
      _poses.add(
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
    if (hasFruit) _elapsed += math.max(0, dt);
  }

  @override
  void render(Canvas canvas) {
    if (!hasFruit || _poses.isEmpty) return;
    final eveHeight = math.min(size.y * 0.34, size.x * 0.27);
    final adamHeight = eveHeight * 1.1;
    final ground = size.y * 0.91;
    void draw(
      Sprite sprite,
      double x,
      double height, {
      bool flip = false,
      double lift = 0,
      double lean = 0,
    }) {
      canvas.save();
      canvas.translate(size.x * x, ground - lift);
      canvas.rotate(lean);
      if (flip) canvas.scale(-1, 1);
      sprite.render(
        canvas,
        anchor: Anchor.bottomCenter,
        size: Vector2(height * sprite.srcSize.x / sprite.srcSize.y, height),
        overridePaint: characterPaint,
      );
      canvas.restore();
    }

    void pose(int index, double x, double height, {bool flip = false}) {
      canvas.save();
      canvas.translate(size.x * x, ground);
      if (flip) canvas.scale(-1, 1);
      _poses[index].render(
        canvas,
        anchor: Anchor.bottomCenter,
        size: Vector2(
          height * crops[index].width / crops[index].height,
          height,
        ),
        overridePaint: characterPaint,
      );
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
    final arriving = action == FruitAction.eating
        ? (_elapsed / 2).clamp(0.0, 1.0)
        : 1.0;
    final adamX = 0.16 + 0.23 * arriving;
    if (bothHaveEaten) {
      final shockTime = action == FruitAction.eating
          ? _elapsed - biteCompletedAt
          : _elapsed + 2;
      final recoil = (shockTime / 0.35).clamp(0.0, 1.0);
      final jolt = math.sin(math.pi * (shockTime / 0.55).clamp(0.0, 1.0));
      // A single realization flash, then a darker scene and visible recoil.
      canvas.drawRect(
        Offset.zero & Size(size.x, size.y),
        Paint()
          ..color = const Color(0xFF101225).withValues(alpha: 0.17 * recoil),
      );
      if (shockTime < 0.4) {
        canvas.drawRect(
          Offset.zero & Size(size.x, size.y),
          Paint()
            ..color = const Color(0xFFFFF1CC)
                .withValues(alpha: 0.22 * (1 - shockTime / 0.4)),
        );
      }
      draw(
        _reactions[0],
        0.39 - 0.012 * recoil,
        adamHeight,
        lift: adamHeight * 0.035 * jolt,
        lean: -0.045 * jolt,
      );
      draw(
        _reactions[shockTime < 1.1 ? 1 : 2],
        0.5 + 0.012 * recoil,
        eveHeight,
        flip: true,
        lift: eveHeight * 0.025 * jolt,
        lean: 0.045 * jolt,
      );
      if (action != FruitAction.awareness) return;
      // Fig leaves gather at their waists, then settle into their loincloths.
      final progress = (_elapsed / 3).clamp(0.0, 1.0);
      for (final x in [0.378, 0.512]) {
        for (var i = 0; i < 3; i++) {
          final center = Offset(
            size.x * x + (i - 1) * eveHeight * 0.075,
            ground - eveHeight * (0.38 + (1 - progress) * 0.15),
          );
          final leaf = Rect.fromCenter(
            center: center,
            width: eveHeight * 0.09,
            height: eveHeight * 0.14,
          );
          canvas.drawOval(
            leaf,
            Paint()
              ..color = const Color(0xFF537B32).withValues(alpha: progress),
          );
          canvas.drawLine(
            leaf.topCenter,
            leaf.bottomCenter,
            Paint()
              ..color = const Color(0xFFADC66A).withValues(alpha: progress)
              ..strokeWidth = 1,
          );
        }
      }
      return;
    }
    if (adamIsWalking) {
      draw(_walk[adamWalkFrame], adamX, adamHeight);
    } else {
      pose(
        eatingStage >= 4
            ? 6
            : eatingStage == 3
            ? 5
            : 0,
        adamX,
        adamHeight,
      );
    }
    pose(
      eatingStage == 0
          ? 1
          : eatingStage == 1
          ? 2
          : 3,
      0.5,
      eveHeight,
      flip: eatingStage != 0,
    );
  }

  @override
  void onRemove() {
    _sheet?.image.dispose();
    _walkingSheet?.image.dispose();
    _reactionSheet?.image.dispose();
    _sheet = null;
    _poses.clear();
    _walk.clear();
    _reactions.clear();
    super.onRemove();
  }
}
