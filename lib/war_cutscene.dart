import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'keyed_art.dart';

/// A timed visual prologue. Every new game owns a fresh, non-looping timeline.
class WarCutscene extends PositionComponent with TapCallbacks {
  WarCutscene({
    required this.onFinished,
    this.onStarted,
    this.videoControlled = false,
  });

  final VoidCallback? onStarted;
  final bool videoControlled;

  final VoidCallback onFinished;
  static const duration = 15.0;
  double elapsed = 0;
  bool isFinished = false;
  Sprite? _kingdom;
  Sprite? _sheet;
  final _fighters = <Sprite>[];
  final _paint = Paint()..isAntiAlias = false;
  late final TextComponent _title;
  late final TextComponent _skip;

  // Hand-fitted source bounds: the supplied sheet is not an even tile grid.
  // Angel sword, spear, bow, then their opposing sword, axe, and bow fighters.
  static const _crops = [
    Rect.fromLTRB(52, 75, 424, 545),
    Rect.fromLTRB(732, 64, 1080, 500),
    Rect.fromLTRB(1395, 175, 1697, 545),
    Rect.fromLTRB(25, 630, 417, 1065),
    Rect.fromLTRB(692, 552, 1068, 1015),
    Rect.fromLTRB(1680, 710, 2025, 1065),
  ];

  String get phase => elapsed < 3
      ? 'THE KINGDOM OF HEAVEN'
      : elapsed < 10
      ? 'ANGELS AGAINST THE DARKNESS'
      : 'THE LIGHT PREVAILS';

  @override
  Future<void> onLoad() async {
    if (!videoControlled) {
      _kingdom = await Sprite.load('kingdom.png');
      _sheet = await loadKeyedArt('warangels.png');
      final image = _sheet!.image;
      for (final crop in _crops) {
        _fighters.add(
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
    TextPaint text(double fontSize) => TextPaint(
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        color: const Color(0xFFFFE5A1),
      ),
    );
    _title = TextComponent(
      text: phase,
      anchor: Anchor.center,
      textRenderer: text(14),
    );
    _skip = TextComponent(
      text: 'SKIP TO GAMEPLAY >',
      anchor: Anchor.center,
      textRenderer: text(12),
    );
    await addAll([_title, _skip]);
    _layout();
    if (videoControlled) {
      _title.text = '';
      _skip.text = '';
    }
  }

  @override
  void onMount() {
    super.onMount();
    onStarted?.call();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
    if (isLoaded) _layout();
  }

  Rect get skipBounds => Rect.fromLTWH(
    math.max(0, size.x - 208),
    size.y - 58,
    math.min(196, size.x),
    46,
  );

  void _layout() {
    _title.position.setValues(size.x / 2, 76);
    _skip.position.setValues(skipBounds.center.dx, skipBounds.center.dy);
  }

  void finishCutscene() {
    if (isFinished || !isMounted) return;
    isFinished = true;
    onFinished();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (skipBounds.contains(event.localPosition.toOffset())) finishCutscene();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isFinished || videoControlled) return;
    elapsed = math.min(duration, elapsed + dt);
    _title.text = phase;
    if (elapsed >= duration) finishCutscene();
  }

  double _progress(double start, double length) =>
      ((elapsed - start) / length).clamp(0.0, 1.0);
  double _smooth(double t) => t * t * (3 - 2 * t);

  @override
  void render(Canvas canvas) {
    if (videoControlled) return;
    if (_kingdom == null || _fighters.isEmpty || size.x <= 0 || size.y <= 0) {
      return;
    }
    canvas.save();
    canvas.clipRect(size.toRect());
    final viewport = size.toSize();
    final fit = applyBoxFit(BoxFit.cover, _kingdom!.srcSize.toSize(), viewport);
    canvas.drawImageRect(
      _kingdom!.image,
      Alignment.center.inscribe(fit.source, _kingdom!.src),
      Offset.zero & viewport,
      _paint
        ..color = const Color(0xFFFFFFFF)
        ..filterQuality = FilterQuality.none,
    );
    canvas.drawRect(size.toRect(), _paint..color = const Color(0x300C1230));

    final entry = _smooth(_progress(0.6, 2.4));
    final defeat = _smooth(_progress(10, 2.8));
    final battle = elapsed >= 3 && elapsed < 10;
    final scale = math.min(size.x / 960, size.y / 540);
    final height = 170 * scale;
    // Separate airborne pairs at three depths; each keeps its own weapon.
    for (final lane in [1, 2, 0]) {
      final laneY = size.y * [0.68, 0.40, 0.60][lane];
      final spread = size.x * [0.17, 0.13, 0.34][lane];
      final cycle = ((elapsed - 3 + lane * 0.38) / 1.6) % 1;
      final lunge = battle
          ? math.pow(math.sin(cycle * math.pi), 8).toDouble()
          : 0.0;
      final approach = lunge * spread * (lane == 2 ? 0.07 : 0.5);
      final bob = math.sin(elapsed * 2.8 + lane * 2) * 6 * scale * (1 - defeat);
      final outside = (1 - entry) * (size.x * 0.6);
      final angelX = size.x / 2 - spread - outside + approach;
      final devilX =
          size.x / 2 + spread + outside - approach + defeat * size.x * 0.45;
      final y = laneY + bob;
      final fighterHeight = height * (lane == 0 ? 1.15 : 0.85);
      _fighter(
        canvas,
        lane,
        Offset(angelX, y),
        fighterHeight,
        false,
        1,
        -lunge * 0.12,
      );
      _fighter(
        canvas,
        lane + 3,
        Offset(devilX, y + defeat * size.y * 0.55),
        fighterHeight,
        true,
        1 - defeat,
        lunge * 0.16 + defeat * 0.8,
      );
      if (battle && lane != 2 && lunge > 0.7) {
        _spark(
          canvas,
          Offset(size.x / 2, y - fighterHeight * 0.1),
          22 * scale,
          cycle * 12,
        );
      }
      if (battle && lane == 2) {
        final shot = ((elapsed - 3) / 1.1) % 1;
        _bolt(
          canvas,
          Offset(angelX + (devilX - angelX) * shot, y - 16 * scale),
          scale,
          true,
        );
        _bolt(
          canvas,
          Offset(devilX - (devilX - angelX) * shot, y + 13 * scale),
          scale,
          false,
        );
      }
    }
    // One golden impact resolves the battle; darkness falls out of the scene.
    if (elapsed >= 10 && elapsed < 11) {
      final pulse = math.sin(_progress(10, 1) * math.pi);
      _spark(
        canvas,
        Offset(size.x * 0.56, size.y * 0.54),
        size.y * 0.35 * pulse,
        0.4,
      );
      canvas.drawRect(
        size.toRect(),
        _paint..color = Color.fromRGBO(255, 236, 163, pulse * 0.3),
      );
    }
    // Fade in from black, then out into the kingdom gameplay.
    final fade = math.max(1 - _progress(0, 0.8), _progress(13.8, 1.2));
    if (fade > 0) {
      canvas.drawRect(
        size.toRect(),
        _paint..color = Color.fromRGBO(9, 14, 32, fade),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 56, size.x, 40),
      _paint..color = const Color(0xB0090E20),
    );
    canvas.drawRect(skipBounds, _paint..color = const Color(0xDD101426));
    canvas.drawRect(
      skipBounds.deflate(1),
      Paint()
        ..color = const Color(0xFFE8C681)
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  void _fighter(
    Canvas canvas,
    int index,
    Offset center,
    double height,
    bool flip,
    double opacity,
    double angle,
  ) {
    if (opacity <= 0) return;
    final sprite = _fighters[index];
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(flip ? -1 : 1, 1);
    final width = height * sprite.srcSize.x / sprite.srcSize.y;
    if (index == 4) {
      // The neighboring dagger intrudes into the axe fighter's rectangular
      // crop below its wing. Exclude that pocket without clipping the wing.
      final notchY = -height / 2 + height * (730 - 552) / (1015 - 552);
      final notchX = -width / 2 + width * (740 - 692) / (1068 - 692);
      canvas.clipPath(
        Path()..addPolygon([
          Offset(-width / 2, -height / 2),
          Offset(width / 2, -height / 2),
          Offset(width / 2, height / 2),
          Offset(notchX, height / 2),
          Offset(notchX, notchY),
          Offset(-width / 2, notchY),
        ], true),
      );
    }
    sprite.render(
      canvas,
      size: Vector2(width, height),
      anchor: Anchor.center,
      overridePaint: Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  void _bolt(Canvas canvas, Offset point, double scale, bool light) {
    canvas.drawRect(
      Rect.fromCenter(center: point, width: 32 * scale, height: 4 * scale),
      _paint..color = Color(light ? 0xFFFFE5A1 : 0xFFB34EED),
    );
    _spark(canvas, point + Offset((light ? 16 : -16) * scale, 0), 6 * scale, 0);
  }

  void _spark(Canvas canvas, Offset center, double radius, double rotation) {
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + rotation;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * radius * 0.25,
        center + direction * radius,
        Paint()
          ..color = Color(i.isEven ? 0xFFFFF5CB : 0xFFFFBE53)
          ..strokeWidth = math.max(2, radius / 10),
      );
    }
  }

  @override
  void onRemove() {
    _sheet?.image.dispose();
    _sheet = null;
    _fighters.clear();
    super.onRemove();
  }
}
