import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'creation_backdrop.dart';
import 'forbidden_tree_backdrop.dart';
import 'keyed_art.dart';

/// A timed field walk, five-second tree insert, and approach to the serpent.
class SerpentEncounter extends PositionComponent {
  SerpentEncounter({bool alreadyArrived = false})
    : _elapsed = alreadyArrived ? arrivalTime : 0;

  static const firstWalkDuration = 4.0;
  static const fadeDuration = 1.0;
  static const forbiddenHoldDuration = 5.0;
  static const forbiddenStart = firstWalkDuration + fadeDuration;
  static const snakeRevealTime = forbiddenStart + 1.2;
  static const returnStart = forbiddenStart + forbiddenHoldDuration;
  static const approachStart = returnStart + fadeDuration;
  static const approachDuration = 4.0;
  static const arrivalTime = approachStart + approachDuration;
  double _elapsed;
  double get elapsed => _elapsed;
  bool get hasArrived => _elapsed >= arrivalTime;
  bool get treeVisible => _elapsed >= returnStart;
  bool get snakeHasAppeared => _elapsed >= snakeRevealTime;
  bool get forbiddenSnakeVisible =>
      snakeHasAppeared && _elapsed < approachStart;
  bool get isWalking =>
      _elapsed < firstWalkDuration ||
      (_elapsed >= approachStart && !hasArrived);
  bool isSpeaking = false;
  final field = CreationBackdrop(
    stages: CreationStage.values.where(
      (s) =>
          s != CreationStage.animals &&
          s != CreationStage.people &&
          s != CreationStage.angels,
    ),
    showFish: false,
  );
  final forbidden = ForbiddenTreeBackdrop();
  Sprite? _treeSheet;
  Sprite? _eveSheet;
  Sprite? _snakeSheet;
  Sprite? _tree;
  final _eveFrames = <Sprite>[];
  final _snakeFrames = <Sprite>[];
  // Keep extracted character pixels solid while leaving the outside clear.
  static Paint get evePaint => Paint()
    ..filterQuality = FilterQuality.low
    ..colorFilter = const ColorFilter.matrix([
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      255,
      -32385,
    ]);
  static const _eveCrops = [
    // Equal canvases, aligned at the pelvis and ground, with room for each stride.
    Rect.fromLTWH(90, 140, 380, 630),
    Rect.fromLTWH(560, 140, 380, 630),
    Rect.fromLTWH(990, 140, 380, 630),
    Rect.fromLTWH(1430, 140, 380, 630),
    Rect.fromLTWH(1880, 140, 380, 630),
    Rect.fromLTWH(2308, 140, 380, 630),
  ];
  static const _snakeCrops = [
    Rect.fromLTWH(55, 950, 440, 510),
    Rect.fromLTWH(505, 950, 440, 510),
    Rect.fromLTWH(950, 950, 440, 510),
  ];
  double get eveProgress => _elapsed < returnStart
      ? 0.06 + 0.22 * _smooth((_elapsed / firstWalkDuration).clamp(0.0, 1.0))
      : 0.28 +
            0.22 *
                _smooth(
                  ((_elapsed - approachStart) / approachDuration).clamp(
                    0.0,
                    1.0,
                  ),
                );
  // Advance poses with distance, slowing the steps as she comes to a stop.
  static const _walkCycle = [1, 2, 3, 4, 5, 2];
  int get eveFrame => isWalking
      ? _walkCycle[((eveProgress - 0.06) / 0.22 * 24).floor() %
            _walkCycle.length]
      : 0;
  int get snakeFrame => isSpeaking ? (_elapsed / 0.22).floor() % 3 : 1;
  double get forbiddenOpacity {
    if (_elapsed < firstWalkDuration || _elapsed >= approachStart) return 0;
    if (_elapsed < forbiddenStart) {
      return _smooth((_elapsed - firstWalkDuration) / fadeDuration);
    }
    if (_elapsed < returnStart) return 1;
    return 1 - _smooth((_elapsed - returnStart) / fadeDuration);
  }

  double _smooth(double value) => value * value * (3 - 2 * value);

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

  @override
  Future<void> onLoad() async {
    await addAll([field, forbidden]);
    for (final layer in field.layers.values) {
      layer.opacity = 1;
    }
    _treeSheet = await loadKeyedArt('tree.png');
    // Use the repaired opaque character cutouts directly; never color-key them.
    _eveSheet = await loadKeyedArt('evewalk-solid.png');
    _snakeSheet = await loadKeyedArt('snake.png');
    // Isolate the central tree, leaving the sheet's corner plants outside.
    _tree = _crop(_treeSheet!, const Rect.fromLTWH(620, 40, 1530, 1496));
    for (final crop in _eveCrops) {
      _eveFrames.add(_crop(_eveSheet!, crop));
    }
    for (final crop in _snakeCrops) {
      _snakeFrames.add(_crop(_snakeSheet!, crop));
    }
  }

  @override
  void updateTree(double dt) {
    _elapsed += math.max(0, dt);
    field.size.setFrom(size);
    forbidden.size.setFrom(size);
    field.updateTree(dt);
  }

  @override
  void renderTree(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0 || _tree == null) return;
    field.size.setFrom(size);
    forbidden.size.setFrom(size);
    final viewport = Offset.zero & size.toSize();
    canvas.save();
    canvas.clipRect(viewport);
    field.renderTree(canvas);
    final ground = size.y * 0.91;
    final treeHeight = math.min(size.y * 0.85, size.x * 0.52);
    final treeWidth = treeHeight * 1530 / 1496;
    final treeRect = Rect.fromLTWH(
      size.x * 0.73 - treeWidth / 2,
      ground - treeHeight,
      treeWidth,
      treeHeight,
    );
    if (treeVisible) {
      _tree!.render(
        canvas,
        position: Vector2(treeRect.left, treeRect.top),
        size: Vector2(treeRect.width, treeRect.height),
        overridePaint: Paint()..filterQuality = FilterQuality.none,
      );
      final snakeHeight = treeHeight * 0.28;
      canvas.save();
      // Face Eve, with the supplied branch resting against the tree's left fork.
      canvas.translate(
        treeRect.left + treeWidth * 0.40,
        treeRect.top + treeHeight * 0.61,
      );
      canvas.scale(-1, 1);
      _snakeFrames[snakeFrame].render(
        canvas,
        size: Vector2(snakeHeight * 440 / 510, snakeHeight),
        anchor: Anchor.bottomCenter,
        overridePaint: Paint()..filterQuality = FilterQuality.none,
      );
      canvas.restore();
    }
    final eveHeight = math.min(size.y * 0.34, size.x * 0.27);
    final crop = _eveCrops[eveFrame];
    _eveFrames[eveFrame].render(
      canvas,
      position: Vector2(size.x * eveProgress, ground),
      size: Vector2(eveHeight * crop.width / crop.height, eveHeight),
      anchor: Anchor.bottomCenter,
      overridePaint: evePaint,
    );
    final opacity = forbiddenOpacity;
    if (opacity > 0) {
      canvas.saveLayer(
        viewport,
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
      );
      forbidden.renderTree(canvas);
      if (forbiddenSnakeVisible) {
        // Use the backdrop's cover transform so the snake stays on the fork
        // in both landscape and portrait. Its entrance is an immediate cut.
        final scale = math.max(size.x / 2752, size.y / 1536);
        canvas.save();
        canvas.translate(
          (size.x - 2752 * scale) / 2,
          (size.y - 1536 * scale) / 2,
        );
        canvas.scale(scale, scale);
        canvas.translate(2752 * 0.44, 1536 * 0.60);
        canvas.scale(-1, 1);
        const height = 1536 * 0.24;
        _snakeFrames[1].render(
          canvas,
          size: Vector2(height * 440 / 510, height),
          anchor: Anchor.bottomCenter,
          overridePaint: Paint()..filterQuality = FilterQuality.none,
        );
        canvas.restore();
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  void onRemove() {
    _treeSheet?.image.dispose();
    _eveSheet?.image.dispose();
    _snakeSheet?.image.dispose();
    _treeSheet = _eveSheet = _snakeSheet = _tree = null;
    _eveFrames.clear();
    _snakeFrames.clear();
    super.onRemove();
  }
}
