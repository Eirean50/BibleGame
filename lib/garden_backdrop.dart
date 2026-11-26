import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'keyed_art.dart';
import 'eden_cliff.dart';
import 'human_character.dart';

/// One camera transform moves the garden and foreground together. The group
/// starts outside the close-up and enters view naturally as the camera retreats.
class GardenBackdrop extends PositionComponent {
  GardenBackdrop({
    bool alreadyRevealed = false,
    bool? alreadyAnimated,
    this.includeEve = false,
  }) : _elapsed = alreadyRevealed ? revealDuration : 0,
       _animationElapsed = (alreadyAnimated ?? alreadyRevealed)
           ? animationDuration
           : 0;

  final bool includeEve;

  static const revealDuration = 12.0;
  double _elapsed;
  Sprite? _garden;
  Sprite? _group;
  Sprite? _adam;
  final _groupFrames = <Sprite>[];
  double _animationElapsed;
  static const frameDuration = 0.7;
  static const animationDuration = frameDuration * 6;
  // Equal-sized crops keep the feet and scale steady across the six poses.
  // Coordinates are relative to the supplied 2048x1143 reference sheet.
  static const _frameCrops = [
    Rect.fromLTWH(88, 140, 580, 430),
    Rect.fromLTWH(744, 140, 580, 430),
    Rect.fromLTWH(1400, 140, 580, 430),
    Rect.fromLTWH(88, 634, 580, 430),
    Rect.fromLTWH(744, 634, 580, 430),
    Rect.fromLTWH(1400, 634, 580, 430),
  ];
  // Render the Creator separately; the original group includes Eve and an
  // overlapping arm. Adam uses his clean standalone pose from the human sheet.
  static const _creatorCrops = [
    Rect.fromLTWH(450, 140, 200, 430),
    Rect.fromLTWH(1100, 140, 224, 430),
    Rect.fromLTWH(1735, 140, 245, 430),
    Rect.fromLTWH(425, 634, 243, 430),
    Rect.fromLTWH(1080, 634, 244, 430),
    Rect.fromLTWH(1736, 634, 244, 430),
  ];
  int get currentFrame => math.min(
    (_animationElapsed / frameDuration).floor(),
    _frameCrops.length - 1,
  );
  bool get isAnimationFinished => _animationElapsed >= animationDuration;
  bool get isRevealed => _elapsed >= revealDuration;
  double get revealProgress => (_elapsed / revealDuration).clamp(0.0, 1.0);
  double get _ease =>
      revealProgress * revealProgress * (3 - 2 * revealProgress);
  double get cameraZoom => 3 - 2 * _ease;
  Offset get _cameraFocus =>
      Offset(size.x * (0.40 + 0.10 * _ease), size.y * (0.18 + 0.32 * _ease));
  Rect get _groupRect {
    final height = math.min(size.y * 0.40, size.x * 0.29);
    final width = height * 580 / 430;
    return Rect.fromLTWH(
      size.x * 0.42 - width / 2,
      size.y * 0.84 - height,
      width,
      height,
    );
  }

  bool get isGroupVisible {
    if (size.x <= 0 || size.y <= 0 || _groupFrames.isEmpty) return false;
    final rect = _groupRect;
    final focus = _cameraFocus;
    final visibleRect = Rect.fromLTWH(
      size.x / 2 + (rect.left - focus.dx) * cameraZoom,
      size.y / 2 + (rect.top - focus.dy) * cameraZoom,
      rect.width * cameraZoom,
      rect.height * cameraZoom,
    );
    // Dialogue overlaps the last 16 pixels of the scenery. Wait until the
    // figures enter the unobscured area, not merely the off-screen world.
    return visibleRect.overlaps(
      Rect.fromLTWH(0, 0, size.x, math.max(0, size.y - 16)),
    );
  }

  @override
  Future<void> onLoad() async {
    _garden = await Sprite.load('garden.png');
    _group = await loadKeyedArt('jesuswithadamandeve.png');
    if (!includeEve) {
      _adam = await loadKeyedArt('human.png');
      final adamCrop = HumanCreation.adamStandingCrop;
      _adam!.srcPosition = Vector2(
        adamCrop.left / 2048 * _adam!.image.width,
        adamCrop.top / 1143 * _adam!.image.height,
      );
      _adam!.srcSize = Vector2(
        adamCrop.width / 2048 * _adam!.image.width,
        adamCrop.height / 1143 * _adam!.image.height,
      );
    }
    final image = _group!.image;
    for (final crop in includeEve ? _frameCrops : _creatorCrops) {
      _groupFrames.add(
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
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final wasVisible = isGroupVisible;
    _elapsed = math.min(revealDuration, _elapsed + dt);
    // Hold pose zero while hidden. The first visible frame also starts at zero;
    // time spent behind the camera must not skip the beginning of the motion.
    if (wasVisible && isGroupVisible) {
      // Play once, then hold the last pose (including on the Level1 route).
      _animationElapsed = math.min(animationDuration, _animationElapsed + dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final garden = _garden;
    final group = _groupFrames.isEmpty ? null : _groupFrames[currentFrame];
    if (garden == null || group == null || size.x <= 0 || size.y <= 0) return;
    final viewport = size.toSize();
    canvas.save();
    canvas.clipRect(Offset.zero & viewport);
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(cameraZoom);
    canvas.translate(-_cameraFocus.dx, -_cameraFocus.dy);
    final fitted = applyBoxFit(BoxFit.cover, garden.srcSize.toSize(), viewport);
    final source = Alignment.center.inscribe(fitted.source, garden.src);
    canvas.drawImageRect(
      garden.image,
      source,
      Offset.zero & viewport,
      Paint()..filterQuality = FilterQuality.none,
    );

    final rect = _groupRect;
    final height = rect.height;
    final width = rect.width;
    drawEdenCliff(canvas, rect);
    if (includeEve) {
      group.render(
        canvas,
        position: Vector2(rect.left, rect.top),
        size: Vector2(width, height),
        overridePaint: Paint()..filterQuality = FilterQuality.none,
      );
      canvas.restore();
      return;
    }
    _adam?.render(
      canvas,
      position: Vector2(rect.left + width * 0.28, rect.bottom),
      size: Vector2(height * 0.95 * 210 / 475, height * 0.95),
      anchor: Anchor.bottomCenter,
      overridePaint: Paint()..filterQuality = FilterQuality.none,
    );
    final crop = _creatorCrops[currentFrame];
    final frame = _frameCrops[currentFrame];
    group.render(
      canvas,
      position: Vector2(
        rect.left + (crop.left - frame.left) / frame.width * width,
        rect.top,
      ),
      size: Vector2(width * crop.width / frame.width, height),
      overridePaint: Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  @override
  void onRemove() {
    _group?.image.dispose();
    _group = null;
    _adam?.image.dispose();
    _adam = null;
    _groupFrames.clear();
    super.onRemove();
  }
}
