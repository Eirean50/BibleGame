import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'keyed_art.dart';
import 'eden_cliff.dart';
import 'narrated_scene.dart';

const List<String> edenScript = [
  'By the seventh day, the heavens and the earth were fully completed.',
  'God rested from all the work He had done, blessing the seventh day and making it holy.',
  'The Creator planted a beautiful garden in the east, in Eden.',
];

class EdenCutscene extends NarratedScene {
  EdenCutscene({required super.onFinished})
    : super(
        script: edenScript,
        heading: 'GENESIS / THE GARDEN OF EDEN',
        endHint: 'TAP TO VIEW THE GARDEN >',
        fixedPanelHeight: true,
      );

  @override
  final GardenBackdrop backdrop = GardenBackdrop();
  bool _revealAnnounced = false;

  @override
  bool get canFinish => backdrop.isRevealed && backdrop.isAnimationFinished;

  @override
  void update(double dt) {
    super.update(dt);
    if (!_revealAnnounced && canFinish) {
      _revealAnnounced = true;
      refreshHint();
    }
  }
}

/// Hold the completed garden after Genesis without repeating the prologue game.
class GardenEnding extends PositionComponent {
  final backdrop = GardenBackdrop(alreadyRevealed: true);

  @override
  Future<void> onLoad() async => add(backdrop);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
    backdrop.size.setFrom(size);
  }
}

/// One camera transform moves the garden and foreground together. The group
/// starts outside the close-up and enters view naturally as the camera retreats.
class GardenBackdrop extends PositionComponent {
  GardenBackdrop({bool alreadyRevealed = false})
    : _elapsed = alreadyRevealed ? revealDuration : 0,
      _animationElapsed = alreadyRevealed ? animationDuration : 0;

  static const revealDuration = 12.0;
  double _elapsed;
  Sprite? _garden;
  Sprite? _group;
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
    final image = _group!.image;
    for (final crop in _frameCrops) {
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
    final feet = rect.bottomCenter;
    drawEdenCliff(canvas, rect);
    group.render(
      canvas,
      position: Vector2(feet.dx, feet.dy),
      size: Vector2(width, height),
      anchor: Anchor.bottomCenter,
      overridePaint: Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  @override
  void onRemove() {
    _group?.image.dispose();
    _group = null;
    _groupFrames.clear();
    super.onRemove();
  }
}
