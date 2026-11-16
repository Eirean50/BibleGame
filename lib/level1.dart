import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keyed_art.dart';
import 'sword_sound.dart';

/// Kingdom movement and sword practice before the Genesis story.
class Level1 extends PositionComponent with KeyboardHandler, TapCallbacks {
  Level1({this.onContinue, SwordSound? swordSound})
    : _swordSound = swordSound ?? SwordSound();

  final VoidCallback? onContinue;
  final SwordSound _swordSound;
  late final SpriteComponent backdrop;
  late final AngelPlayer player;
  late final DevilEnemy enemy;
  late final JoystickComponent joystick;
  late final TextComponent _hint;
  late final KingdomButton attackButton;
  late final KingdomButton continueButton;
  late final KingdomButton retryButton;
  bool _ready = false;
  bool _spawned = false;
  bool _leaving = false;
  bool _retryShown = false;
  double _enemyCooldown = 0.8;
  static const sceneZoom = 1.45;

  static final movementKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight,
  };

  double get movementSpeed => math.min(size.x, size.y) * 0.45;

  @override
  Future<void> onLoad() async {
    backdrop = SpriteComponent(
      sprite: await Sprite.load('kingdom.png'),
      anchor: Anchor.center,
    );
    player = AngelPlayer(await loadKeyedArt('angel_avatar.png'));
    enemy = DevilEnemy(await loadKeyedArt('devil.png'));
    player.onStrike = () => _strike(player, enemy, 25);
    enemy.onStrike = () => _strike(enemy, player, 10);
    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 22,
        paint: Paint()..color = const Color(0xD9FFE6B7),
      ),
      background: CircleComponent(
        radius: 54,
        paint: Paint()..color = const Color(0x80503F64),
        children: [
          CircleComponent(
            radius: 54,
            paint: Paint()
              ..color = const Color(0xB3FFE6B7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          ),
        ],
      ),
    );
    _hint = TextComponent(
      text: 'Galaw: joystick / WASD / arrows  |  Attack: tap / Space',
      anchor: Anchor.bottomCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          color: Color(0xFFFFF2D7),
          shadows: [Shadow(color: Color(0xFF211C26), blurRadius: 5)],
        ),
      ),
    );
    attackButton = KingdomButton(
      label: 'ATTACK',
      onPressed: attack,
      circular: true,
    );
    continueButton = KingdomButton(
      label: 'GENESIS >',
      onPressed: continueToGenesis,
    );
    retryButton = KingdomButton(
      label: 'ULITIN LABAN',
      onPressed: restartBattle,
    );
    await addAll([
      backdrop,
      player,
      enemy,
      FighterHealthBar(player, const Color(0xFF72E6A1)),
      FighterHealthBar(enemy, const Color(0xFFF16D76)),
      joystick,
      attackButton,
      if (onContinue != null) continueButton,
      _hint,
    ]);
    _ready = true;
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    final previousSize = this.size.clone();
    super.onGameResize(size);
    this.size.setFrom(size);
    if (_ready && previousSize.x > 0 && previousSize.y > 0) {
      player.position.setValues(
        player.x / previousSize.x * size.x,
        player.y / previousSize.y * size.y,
      );
      enemy.position.setValues(
        enemy.x / previousSize.x * size.x,
        enemy.y / previousSize.y * size.y,
      );
    }
    _layout();
  }

  void _layout() {
    if (!_ready || size.x <= 0 || size.y <= 0) return;
    final source = backdrop.sprite!.srcSize;
    final zoom = math.max(size.x / source.x, size.y / source.y) * sceneZoom;
    backdrop.size.setFrom(source * zoom);
    backdrop.position.setFrom(size / 2);
    // Bring the fight closer while keeping both fighters visible on narrow screens.
    final height = math.min(
      (size.y * 0.26 * sceneZoom).clamp(64.0, 210.0),
      size.x * 0.4,
    );
    player.size.setValues(height * 0.96, height);
    enemy.size.setFrom(player.size);
    if (!_spawned) {
      _placeFighters();
      _spawned = true;
    }
    joystick.scale.setAll((size.y / 430).clamp(0.7, 1.0));
    final radius = joystick.width * joystick.scale.x / 2;
    joystick.position.setValues(20 + radius, size.y - 28 - radius);
    attackButton.scale.setFrom(joystick.scale);
    attackButton.position.setValues(size.x - 20 - radius, size.y - 28 - radius);
    continueButton.position.setValues(size.x / 2, 32);
    retryButton.position.setValues(size.x / 2, 84);
    _hint.position.setValues(size.x / 2, size.y - 6);
    _hint.scale.setAll(math.min(1, (size.x - 24) / _hint.width));
    _keepPlayerOnScreen();
    _keepFighterOnScreen(enemy);
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) attack();
      return false;
    }
    return !movementKeys.contains(event.logicalKey);
  }

  @override
  void onTapUp(TapUpEvent event) {
    // A tap on the movement pad must not also swing the sword.
    if (joystick.toRect().contains(event.localPosition.toOffset())) return;
    attack();
  }

  void attack() {
    if (!_ready || _leaving || player.isDefeated || !player.startAttack()) {
      return;
    }
    unawaited(_swordSound.play());
  }

  void continueToGenesis() {
    if (!_ready || _leaving || onContinue == null) return;
    _leaving = true;
    stopMovement();
    onContinue!();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_ready || _leaving) return;
    if (player.isDefeated || enemy.isDefeated) {
      enemy.isMoving = false;
      if (!_retryShown) {
        _retryShown = true;
        add(retryButton);
      }
    }
    if (player.isDefeated) {
      player.isMoving = false;
      return;
    }
    // Read current hardware state so releases outside the game do not leave
    // a cached direction stuck when the window regains focus.
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    bool pressed(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        keys.contains(a) || keys.contains(b);
    final direction = Vector2(
      (pressed(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight)
              ? 1
              : 0) -
          (pressed(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft)
              ? 1
              : 0),
      (pressed(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) ? 1 : 0) -
          (pressed(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp)
              ? 1
              : 0),
    );
    direction.add(joystick.relativeDelta);
    if (direction.length2 > 1) direction.normalize();
    player.isMoving = direction.length2 > 0.001;
    if (player.isMoving) {
      if (!player.isAttacking && direction.x.abs() > 0.01) {
        player.scale.x = direction.x < 0 ? -1 : 1;
      }
      player.position.add(direction * movementSpeed * dt);
      _keepPlayerOnScreen();
    }
    _updateEnemy(dt);
  }

  void _placeFighters() {
    player.position.setValues(size.x * 0.32, size.y * 0.62);
    enemy.position.setValues(size.x * 0.76, size.y * 0.62);
    player.scale.x = 1;
    enemy.scale.x = -1;
  }

  void restartBattle() {
    if (!_ready || _leaving) return;
    stopMovement();
    player.restoreHealth();
    enemy.restoreHealth();
    _enemyCooldown = 0.8;
    _placeFighters();
    _keepPlayerOnScreen();
    _keepFighterOnScreen(enemy);
    if (_retryShown) retryButton.removeFromParent();
    _retryShown = false;
  }

  void _updateEnemy(double dt) {
    if (enemy.isDefeated) return;
    _enemyCooldown = math.max(0, _enemyCooldown - dt);
    enemy.isMoving = false;
    if (enemy.isAttacking || enemy.isHurt) return;
    final delta = player.position - enemy.position;
    // Guard the kingdom until the player approaches; idle uses the sword pose.
    if (delta.length > player.height * 2.0) return;
    if (delta.x.abs() > 1) enemy.scale.x = delta.x < 0 ? -1 : 1;
    if (delta.length > player.height * 0.62) {
      enemy.isMoving = true;
      final travel = math.min(
        movementSpeed * 0.48 * math.min(dt, 0.1),
        delta.length - player.height * 0.62,
      );
      enemy.position.add(delta.normalized() * travel);
      _keepFighterOnScreen(enemy);
    } else if (_enemyCooldown <= 0 && enemy.startAttack()) {
      _enemyCooldown = 1.2;
    }
  }

  void _strike(KingdomFighter attacker, KingdomFighter target, int damage) {
    if (_leaving || attacker.isDefeated || target.isDefeated) return;
    final delta = target.position - attacker.position;
    final forward = delta.x * attacker.scale.x;
    final reach = attacker.height * 0.82 + target.width * 0.2;
    if (forward >= -target.width * 0.15 &&
        forward <= reach &&
        delta.y.abs() <= attacker.height * 0.4) {
      target.takeDamage(damage);
    }
  }

  void stopMovement() {
    if (!_ready) return;
    joystick.onDragStop();
    joystick.update(0);
    player.isMoving = false;
    player.cancelAttack();
    enemy.isMoving = false;
    enemy.cancelAttack();
    unawaited(_swordSound.stop());
  }

  @override
  void onRemove() {
    disposeAudio();
    super.onRemove();
  }

  void disposeAudio() => unawaited(_swordSound.dispose());

  void _keepPlayerOnScreen() => _keepFighterOnScreen(player);

  void _keepFighterOnScreen(KingdomFighter fighter) {
    final half = fighter.size / 2;
    fighter.x = fighter.x.clamp(
      half.x + 8,
      math.max(half.x + 8, size.x - half.x - 8),
    );
    fighter.y = fighter.y.clamp(
      half.y + 18,
      math.max(half.y + 18, size.y - half.y - 8),
    );
  }
}

class AngelPlayer extends KingdomFighter {
  AngelPlayer(super.sheet) : super(isDevil: false);
  static const attackDuration = KingdomFighter.attackDuration;
}

class DevilEnemy extends KingdomFighter {
  DevilEnemy(super.sheet) : super(isDevil: true);
}

class KingdomFighter extends PositionComponent {
  KingdomFighter(this._sheet, {required this.isDevil})
    : super(anchor: Anchor.center) {
    // Hand-fitted poses from the supplied irregular 2752x1536 sheet.
    // Coordinates use a 2048x1143 reference, scaled to the prepared texture.
    Sprite pose(Rect crop) => Sprite(
      _sheet.image,
      srcPosition: Vector2(
        crop.left / 2048 * _sheet.image.width,
        crop.top / 1143 * _sheet.image.height,
      ),
      srcSize: Vector2(
        crop.width / 2048 * _sheet.image.width,
        crop.height / 1143 * _sheet.image.height,
      ),
    );
    _idle = pose(const Rect.fromLTRB(48, 130, 416, 514));
    // Forward flight with swept-back wings, matching both movement references.
    _moving = pose(const Rect.fromLTRB(394, 92, 710, 508));
    _attackFrames = isDevil
        ? [
            _idle,
            pose(const Rect.fromLTRB(1060, 86, 1316, 518)),
            pose(const Rect.fromLTRB(1060, 86, 1316, 518)),
          ]
        : [
            pose(const Rect.fromLTRB(10, 545, 400, 1065)),
            pose(const Rect.fromLTRB(400, 545, 732, 1065)),
            pose(const Rect.fromLTRB(735, 545, 1095, 1065)),
          ];
  }

  final Sprite _sheet;
  final bool isDevil;
  VoidCallback? onStrike;
  static const maxHealth = 100;
  int _health = maxHealth;
  int get health => _health;
  double get healthFraction => _health / maxHealth;
  bool get isDefeated => _health == 0;
  double _hurtTime = 0;
  bool get isHurt => _hurtTime > 0;
  late final Sprite _idle;
  late final Sprite _moving;
  late final List<Sprite> _attackFrames;
  final _paint = Paint()..filterQuality = FilterQuality.none;
  bool isMoving = false;
  double _elapsed = 0;
  static const attackDuration = 0.42;
  double _attackElapsed = 1;
  double get swingDuration => isDevil ? 0.65 : attackDuration;
  bool get isAttacking => _attackElapsed < swingDuration;
  double get attackProgress => (_attackElapsed / swingDuration).clamp(0.0, 1.0);

  bool startAttack() {
    if (isAttacking || isDefeated || isHurt) return false;
    _attackElapsed = 0;
    return true;
  }

  void cancelAttack() => _attackElapsed = swingDuration;

  void takeDamage(int damage) {
    if (damage <= 0 || isDefeated) return;
    _health = math.max(0, _health - damage);
    _hurtTime = 0.2;
    isMoving = false;
    cancelAttack();
  }

  void restoreHealth() {
    _health = maxHealth;
    _hurtTime = 0;
    isMoving = false;
    cancelAttack();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _hurtTime = math.max(0, _hurtTime - dt);
    final before = attackProgress;
    _attackElapsed = math.min(swingDuration, _attackElapsed + dt);
    if (!isDefeated && before < 0.42 && attackProgress >= 0.42) {
      onStrike?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    if (isDefeated) {
      canvas.translate(size.x / 2, size.y * 0.82);
      canvas.rotate(math.pi / 2);
      canvas.scale(0.8);
      canvas.translate(-size.x / 2, -size.y / 2);
    }
    final sprite = isAttacking
        ? _attackFrames[attackProgress < 0.22
              ? 0
              : attackProgress < 0.58
              ? 1
              : 2]
        : isMoving
        ? _moving
        : _idle;
    // All attack crops share a ground line; the raised sword has extra space.
    final height = (size.y - 6) * (isAttacking && !isDevil ? 520 / 395 : 1);
    final drawSize = Vector2(
      height * sprite.srcSize.x / sprite.srcSize.y,
      height,
    );
    final feet = Vector2(
      size.x / 2,
      size.y - 3 + (isDefeated ? 0 : math.sin(_elapsed * 3) * 2),
    );
    _paint.color = Color.fromRGBO(255, 255, 255, isDefeated ? 0.45 : 1);
    _paint.colorFilter = isHurt && !isDefeated
        ? const ColorFilter.mode(Color(0x99FF7272), BlendMode.srcATop)
        : null;
    canvas.save();
    if (identical(sprite, _idle)) {
      // Exclude the adjacent pose's wing in the upper-right corner only.
      final left = feet.x - drawSize.x / 2;
      final top = feet.y - drawSize.y;
      final notchX = left + drawSize.x * (392 - 48) / 368;
      final notchY = top + drawSize.y * 160 / 384;
      canvas.clipPath(
        Path()..addPolygon([
          Offset(left, top),
          Offset(notchX, top),
          Offset(notchX, notchY),
          Offset(left + drawSize.x, notchY),
          Offset(left + drawSize.x, feet.y),
          Offset(left, feet.y),
        ], true),
      );
    } else if (identical(sprite, _moving)) {
      // The standing pose's sword tip intrudes at the lower-left of this crop.
      // Keep the wide upper wing, but exclude that neighboring sword fragment.
      final left = feet.x - drawSize.x / 2;
      final top = feet.y - drawSize.y;
      final notchX = left + drawSize.x * (420 - 394) / 316;
      final notchY = top + drawSize.y * (310 - 92) / 416;
      canvas.clipPath(
        Path()..addPolygon([
          Offset(left, top),
          Offset(left + drawSize.x, top),
          Offset(left + drawSize.x, feet.y),
          Offset(notchX, feet.y),
          Offset(notchX, notchY),
          Offset(left, notchY),
        ], true),
      );
    }
    sprite.render(
      canvas,
      position: feet,
      size: drawSize,
      anchor: Anchor.bottomCenter,
      overridePaint: _paint,
    );
    canvas.restore();
    if (isAttacking) _renderSlash(canvas);
    canvas.restore();
  }

  void _renderSlash(Canvas canvas) {
    final t = ((attackProgress - 0.12) / 0.78).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return;
    final opacity = math.sin(t * math.pi);
    final center = Offset(size.x * 0.55, size.y * 0.53);
    final radius = size.y * 0.72;
    final outer = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 1.65,
    );
    final inner = outer.deflate(size.y * 0.13 * opacity);
    final start = -1.65 + t * 0.7;
    final sweep = 1.9 + t * 0.65;
    final trail = Path()
      ..arcTo(outer, start, sweep, true)
      ..arcTo(inner, start + sweep, -sweep, false)
      ..close();
    canvas.drawPath(
      trail,
      Paint()
        ..color = Color.fromRGBO(255, isDevil ? 35 : 161, 42, opacity * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      trail,
      Paint()
        ..color = Color.fromRGBO(
          255,
          isDevil ? 80 : 225,
          isDevil ? 95 : 126,
          opacity * 0.95,
        ),
    );
    canvas.drawArc(
      outer,
      start,
      sweep,
      false,
      Paint()
        ..color = Color.fromRGBO(255, 255, 230, opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, size.y * 0.018)
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 6; i++) {
      final angle = start + sweep * (i / 5);
      final distance = radius * (1 + t * 0.26);
      final spark =
          center + Offset(math.cos(angle), math.sin(angle) * 0.825) * distance;
      canvas.drawCircle(
        spark,
        size.y * 0.013 * (1 - t),
        Paint()..color = Color.fromRGBO(255, 241, 170, opacity),
      );
    }
  }

  @override
  void onRemove() {
    _sheet.image.dispose();
    super.onRemove();
  }
}

/// Drawn in level coordinates so facing left never reverses the health fill.
class FighterHealthBar extends Component {
  FighterHealthBar(this.fighter, this.color);

  final KingdomFighter fighter;
  final Color color;

  Rect get bounds => Rect.fromCenter(
    center: Offset(fighter.x, fighter.y - fighter.height / 2 - 9),
    width: (fighter.height * 0.32).clamp(28.0, 44.0),
    height: 5,
  );

  @override
  void render(Canvas canvas) {
    final rect = bounds;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(1.5), const Radius.circular(3)),
      Paint()..color = const Color(0xE6191924),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF543C49),
    );
    if (fighter.health > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left,
            rect.top,
            rect.width * fighter.healthFraction,
            rect.height,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = color,
      );
    }
  }
}

class KingdomButton extends PositionComponent with TapCallbacks {
  KingdomButton({
    required this.label,
    required this.onPressed,
    this.circular = false,
  }) : super(
         size: circular ? Vector2.all(108) : Vector2(156, 42),
         anchor: Anchor.center,
       );

  final String label;
  final VoidCallback onPressed;
  final bool circular;

  @override
  Future<void> onLoad() async {
    await add(
      TextComponent(
        text: label,
        anchor: Anchor.center,
        position: Vector2(size.x / 2, circular ? 80 : size.y / 2),
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFE6B7),
          ),
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      Radius.circular(circular ? 54 : 10),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xBD30263E));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xCCFFE6B7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (circular) {
      final sword = Paint()
        ..color = const Color(0xFFFFE6B7)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(40, 57), const Offset(70, 27), sword);
      canvas.drawLine(const Offset(37, 45), const Offset(51, 59), sword);
      canvas.drawLine(
        const Offset(35, 62),
        const Offset(43, 54),
        sword..color = const Color(0xFFE9AC52),
      );
    }
  }

  @override
  void onTapUp(TapUpEvent event) => onPressed();
}
