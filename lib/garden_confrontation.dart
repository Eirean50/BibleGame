import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'forbidden_fruit_actors.dart';
import 'keyed_art.dart';

/// Genesis 3:8–13. Movement is staged around the foreground tree, never faded.
class GardenConfrontation extends PositionComponent {
  GardenConfrontation({required this.characterPaint, bool completed = false})
    : _scene = completed ? 23 : -1,
      _elapsed = completed ? 5 : 0,
      _eveAccusing = completed,
      _pointingElapsed = completed ? 2 : 0;

  final Paint characterPaint;
  int _scene;
  double _elapsed;
  double _returnElapsed = 0;
  double _pointingElapsed;
  bool _called = false;
  bool _eveAccusing;
  final _sheets = <Sprite>[];
  final _adamWalk = <Sprite>[];
  final _eveWalk = <Sprite>[];
  final _jesusWalk = <Sprite>[];
  final _jesusShock = <Sprite>[];
  Sprite? _jesusCalling;
  final _fear = <Sprite>[];
  final _pointing = <Sprite>[];
  static const hideDuration = 1.3;
  static const entranceDuration = 3.2;
  static const returnDuration = 1.8;

  bool get active => _scene >= 18;
  bool get footstepsStarted =>
      active && (_scene > 18 || _elapsed >= hideDuration);
  bool get jesusWalking =>
      _scene == 18 &&
      _elapsed >= hideDuration &&
      _elapsed < hideDuration + entranceDuration;
  bool get coupleReturning =>
      _scene == 19 && _called && _returnElapsed < returnDuration;
  bool get coupleHidden =>
      (_scene == 18 && _elapsed >= hideDuration) || (_scene == 19 && !_called);
  bool get adamPointing => _scene == 22;
  bool get evePointing => _scene == 23 && _eveAccusing;
  bool get jesusShocked => _scene == 23;
  bool get canLeaveScene => switch (_scene) {
    18 => _elapsed >= 5,
    19 => _called && _returnElapsed >= returnDuration,
    22 => _elapsed >= 1.2,
    23 => _eveAccusing && _pointingElapsed >= 1.2,
    _ => _elapsed >= 0.8,
  };

  void showScene(int scene) {
    if (scene == _scene) return;
    _scene = scene;
    _elapsed = 0;
    _returnElapsed = 0;
    _called = false;
    _eveAccusing = false;
    _pointingElapsed = 0;
  }

  void answerCall() {
    if (_scene == 19) _called = true;
  }

  void accuseSerpent() {
    if (_scene == 23) _eveAccusing = true;
  }

  Sprite _crop(
    Sprite sheet,
    Rect crop, {
    double width = 2752,
    double height = 1536,
  }) => Sprite(
    sheet.image,
    srcPosition: Vector2(
      crop.left / width * sheet.image.width,
      crop.top / height * sheet.image.height,
    ),
    srcSize: Vector2(
      crop.width / width * sheet.image.width,
      crop.height / height * sheet.image.height,
    ),
  );

  @override
  Future<void> onLoad() async {
    for (final name in [
      'adamwalking-solid.png',
      'evewalk-solid.png',
      'jesuswalking-solid.png',
      'jesusshocked-solid.png',
      'evetalking-solid.png',
      'adampoint-solid.png',
      'jesusangry-solid.png',
      'evepoint-solid.png',
    ]) {
      _sheets.add(await loadKeyedArt(name));
    }
    // User-selected standing, speaking and pointing pose: top row, fifth.
    _jesusCalling = _crop(_sheets[6], const Rect.fromLTWH(1930, 145, 330, 620));
    for (final crop in ForbiddenFruitActors.walkCrops) {
      _adamWalk.add(_crop(_sheets[0], crop));
    }
    for (final x in [90.0, 560.0, 990.0, 1430.0, 1880.0, 2308.0]) {
      _eveWalk.add(_crop(_sheets[1], Rect.fromLTWH(x, 140, 380, 630)));
    }
    for (final x in [135.0, 570.0, 1010.0, 1430.0, 1855.0, 2285.0]) {
      _jesusWalk.add(_crop(_sheets[2], Rect.fromLTWH(x, 145, 370, 620)));
    }
    for (final crop in [
      const Rect.fromLTWH(160, 145, 270, 620),
      const Rect.fromLTWH(1460, 145, 340, 620),
      const Rect.fromLTWH(1910, 145, 335, 620),
    ]) {
      _jesusShock.add(_crop(_sheets[3], crop));
    }
    _fear.addAll([
      _crop(_sheets[0], const Rect.fromLTWH(1900, 910, 310, 585)),
      _crop(_sheets[4], const Rect.fromLTWH(165, 920, 290, 580)),
      _crop(_sheets[4], const Rect.fromLTWH(615, 920, 245, 580)),
      _crop(_sheets[5], const Rect.fromLTWH(620, 160, 225, 600)),
      _crop(_sheets[7], const Rect.fromLTWH(600, 155, 270, 610)),
    ]);
    _pointing.addAll([
      _crop(_sheets[5], const Rect.fromLTWH(1940, 165, 315, 600)),
      _crop(_sheets[7], const Rect.fromLTWH(1070, 155, 340, 610)),
    ]);
  }

  @override
  void update(double dt) {
    if (!active) return;
    final step = math.max(0.0, dt);
    _elapsed += step;
    if (_called) _returnElapsed += step;
    if (_eveAccusing) _pointingElapsed += step;
  }

  double _smooth(double t) {
    final p = t.clamp(0.0, 1.0);
    return p * p * (3 - 2 * p);
  }

  double get _eveHeight => math.min(size.y * 0.34, size.x * 0.27);
  void _draw(
    Canvas canvas,
    Sprite sprite,
    double x,
    double height, {
    bool flip = false,
    double pelvis = 0.5,
  }) {
    canvas.save();
    canvas.translate(size.x * x, size.y * 0.91);
    if (flip) canvas.scale(-1, 1);
    sprite.render(
      canvas,
      anchor: Anchor(pelvis, 1),
      size: Vector2(height * sprite.srcSize.x / sprite.srcSize.y, height),
      overridePaint: characterPaint,
    );
    canvas.restore();
  }

  /// The trunk and foliage paint over the moving couple.
  void renderBehindTree(Canvas canvas) {
    if (!active || _sheets.isEmpty || coupleHidden) return;
    if (_scene != 18 && !coupleReturning) return;
    final hiding = _scene == 18;
    final t = _smooth(
      hiding ? _elapsed / hideDuration : _returnElapsed / returnDuration,
    );
    final adamX = hiding
        ? 0.378 + (0.73 - 0.378) * t
        : 0.73 + (0.40 - 0.73) * t;
    final eveX = hiding ? 0.512 + (0.73 - 0.512) * t : 0.73 + (0.53 - 0.73) * t;
    final frame = ((_elapsed * (hiding ? 12 : 8)).floor() % 5) + 1;
    _draw(canvas, _adamWalk[frame], adamX, _eveHeight * 1.1, flip: !hiding);
    _draw(canvas, _eveWalk[frame], eveX, _eveHeight, flip: !hiding);
  }

  @override
  void render(Canvas canvas) {
    if (!active || _sheets.isEmpty) return;
    if (footstepsStarted) {
      final progress = _scene == 18
          ? _smooth((_elapsed - hideDuration) / entranceDuration)
          : 1.0;
      final frame = jesusWalking ? ((_elapsed * 7).floor() % 5) + 1 : 0;
      final jesus = jesusShocked
          ? _jesusShock[_eveAccusing ? 2 : 1]
          : _scene == 19
          ? _jesusCalling!
          : _scene == 21
          ? _jesusShock[0]
          : _jesusWalk[frame];
      _draw(canvas, jesus, -0.08 + 0.31 * progress, _eveHeight * 1.15);
    }
    if (_scene == 18 || coupleHidden || coupleReturning) return;
    if (adamPointing) {
      _draw(canvas, _pointing[0], 0.40, _eveHeight * 1.1, pelvis: 0.38);
    } else {
      _draw(
        canvas,
        _fear[evePointing ? 3 : 0],
        0.40,
        _eveHeight * 1.1,
        flip: true,
      );
    }
    if (evePointing) {
      _draw(canvas, _pointing[1], 0.53, _eveHeight, pelvis: 0.30);
    } else {
      _draw(canvas, _fear[adamPointing ? 4 : 2], 0.53, _eveHeight, flip: true);
    }
  }

  @override
  void onRemove() {
    for (final sheet in _sheets) {
      sheet.image.dispose();
    }
    _sheets.clear();
    _adamWalk.clear();
    _eveWalk.clear();
    _jesusWalk.clear();
    _jesusShock.clear();
    _jesusCalling = null;
    _fear.clear();
    _pointing.clear();
    super.onRemove();
  }
}
