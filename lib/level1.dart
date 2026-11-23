import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keyed_art.dart';
import 'sword_sound.dart';

/// Playable angel-led team battle before the Genesis story.
class Level1 extends PositionComponent with KeyboardHandler, TapCallbacks {
  Level1({
    this.onContinue,
    SwordSound? swordSound,
    SwordSound? enemySound,
    SwordSound? ambienceSound,
    this.reinforcements = 3,
  }) : _swordSound = swordSound ?? SwordSound(),
       _enemySound = enemySound ?? SwordSound(),
       _ambienceSound =
           ambienceSound ??
           SwordSound(asset: battleAudioAsset, volume: 0.65, loop: true);

  final VoidCallback? onContinue;
  final SwordSound _swordSound;
  final SwordSound _enemySound;
  final SwordSound _ambienceSound;
  static const battleAudioAsset = 'audio/warnew_battle.m4a';
  final int reinforcements;
  final allies = <KingdomFighter>[];
  final additionalEnemies = <DevilEnemy>[];
  Iterable<KingdomFighter> get angelTeam => [player, ...allies];
  Iterable<KingdomFighter> get devilTeam => [enemy, ...additionalEnemies];
  Iterable<KingdomFighter> get fighters => [...angelTeam, ...devilTeam];
  bool get battleOver =>
      player.isDefeated || devilTeam.every((fighter) => fighter.isDefeated);
  final _aiCooldowns = <KingdomFighter, double>{};
  final _aiTargets = <KingdomFighter, KingdomFighter>{};
  bool _ambiencePlaying = false;
  static const ultimateCooldown = 30.0;
  static const ultimateHealing = 35;
  static const ultimateDamage = 50;
  double ultimateCooldownRemaining = 0;
  bool get canUseUltimate =>
      _ready &&
      !_leaving &&
      !player.isDefeated &&
      !battleOver &&
      !player.isUltimateActive &&
      ultimateCooldownRemaining <= 0;
  late final SpriteComponent backdrop;
  late final AngelPlayer player;
  late final DevilEnemy enemy;
  late final JoystickComponent joystick;
  late final TextComponent _hint;
  late final KingdomButton attackButton;
  late final KingdomButton ultimateButton;
  late final KingdomButton continueButton;
  late final KingdomButton retryButton;
  bool _ready = false;
  bool _spawned = false;
  bool _leaving = false;
  bool _retryShown = false;
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
      priority: -1000,
    );
    player = AngelPlayer(
      await loadKeyedArt('angel_avatar.png'),
      await loadKeyedArt('angeldamage.png'),
      await loadKeyedArt('ultiangels.png'),
    );
    enemy = DevilEnemy(
      await loadKeyedArt('devil.png'),
      await loadKeyedArt('devildamage.png'),
    );
    for (var i = 0; i < reinforcements; i++) {
      allies.add(
        KingdomFighter(
          await loadKeyedArt('angel_avatar.png'),
          await loadKeyedArt('angeldamage.png'),
          isDevil: false,
        ),
      );
      additionalEnemies.add(
        DevilEnemy(
          await loadKeyedArt('devil.png'),
          await loadKeyedArt('devildamage.png'),
        ),
      );
    }
    for (final fighter in [...allies, ...devilTeam]) {
      _aiCooldowns[fighter] = 0.8;
      fighter.onStrike = () {
        final target = _aiTargets[fighter];
        if (target != null) _strike(fighter, target, fighter.isDevil ? 10 : 12);
      };
    }
    player.onAttack = () => unawaited(_swordSound.play());
    enemy.onAttack = () => unawaited(_enemySound.play());
    player.onStrike = () {
      for (final target in devilTeam) {
        _strike(player, target, 25);
      }
    };
    // Keep direct attacks useful before the first AI update as well.
    _aiTargets[enemy] = player;
    player.onUltimateStrike = () {
      if (_leaving || player.isDefeated) return;
      for (final target in devilTeam) {
        if (!target.isDefeated &&
            player.position.distanceTo(target.position) <= player.height * 2) {
          target.takeDamage(ultimateDamage);
        }
      }
    };
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
      text: 'Galaw: joystick / WASD  |  Attack: Space  |  Ulti: Q (heal + attack)',
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
    ultimateButton = KingdomButton(label: 'ULTI [Q]', onPressed: useUltimate);
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
      ...allies,
      ...additionalEnemies,
      player,
      enemy,
      for (final fighter in angelTeam)
        FighterHealthBar(fighter, const Color(0xFF72E6A1)),
      for (final fighter in devilTeam)
        FighterHealthBar(fighter, const Color(0xFFF16D76)),
      joystick,
      attackButton,
      ultimateButton,
      if (onContinue != null) continueButton,
      _hint,
    ]);
    _ready = true;
    _layout();
  }

  @override
  void onMount() {
    super.onMount();
    resumeBattleAudio();
  }

  void resumeBattleAudio() {
    if (!_ready ||
        _leaving ||
        player.isDefeated ||
        battleOver ||
        _ambiencePlaying) {
      return;
    }
    _ambiencePlaying = true;
    unawaited(_ambienceSound.play());
  }

  @override
  void onGameResize(Vector2 size) {
    final previousSize = this.size.clone();
    super.onGameResize(size);
    this.size.setFrom(size);
    if (_ready && previousSize.x > 0 && previousSize.y > 0) {
      for (final fighter in fighters) {
        fighter.position.setValues(
          fighter.x / previousSize.x * size.x,
          fighter.y / previousSize.y * size.y,
        );
      }
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
    for (final fighter in [...allies, ...additionalEnemies]) {
      fighter.size.setFrom(player.size * 0.62);
      fighter.priority = -10;
    }
    if (!_spawned) {
      _placeFighters();
      _spawned = true;
    }
    joystick.scale.setAll((size.y / 430).clamp(0.7, 1.0));
    final radius = joystick.width * joystick.scale.x / 2;
    joystick.position.setValues(20 + radius, size.y - 28 - radius);
    attackButton.scale.setFrom(joystick.scale);
    attackButton.position.setValues(size.x - 20 - radius, size.y - 28 - radius);
    ultimateButton.scale.setFrom(joystick.scale);
    ultimateButton.position.setValues(
      math.min(attackButton.x, size.x - 12 - 78 * joystick.scale.x),
      attackButton.y - radius - 32 * joystick.scale.x,
    );
    continueButton.position.setValues(size.x / 2, 32);
    retryButton.position.setValues(size.x / 2, 84);
    _hint.position.setValues(size.x / 2, size.y - 6);
    _hint.scale.setAll(math.min(1, (size.x - 24) / _hint.width));
    for (final fighter in fighters) {
      _keepFighterOnScreen(fighter);
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event.logicalKey == LogicalKeyboardKey.keyQ) {
      if (event is KeyDownEvent) useUltimate();
      return false;
    }
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
  }

  void useUltimate() {
    if (!canUseUltimate) return;
    ultimateCooldownRemaining = ultimateCooldown;
    player.heal(ultimateHealing);
    for (final ally in allies) {
      if (player.position.distanceTo(ally.position) <= player.height * 2) {
        ally.heal(ultimateHealing);
      }
    }
    player.startUltimate();
    unawaited(_swordSound.play());
    _updateUltimateButton();
  }

  void _updateUltimateButton() {
    ultimateButton.label = ultimateCooldownRemaining > 0
        ? 'ULTI ${ultimateCooldownRemaining.ceil()}s'
        : 'ULTI [Q]';
    ultimateButton.enabled = canUseUltimate;
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
    ultimateCooldownRemaining = math.max(0, ultimateCooldownRemaining - dt);
    _updateUltimateButton();
    if (battleOver) {
      if (!_retryShown) {
        stopMovement();
        _retryShown = true;
        add(retryButton);
      }
    }
    if (player.isDefeated) {
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
    player.isMoving =
        !player.isHurt && !player.isUltimateActive && direction.length2 > 0.001;
    if (player.isMoving) {
      if (!player.isAttacking && direction.x.abs() > 0.01) {
        player.scale.x = direction.x < 0 ? -1 : 1;
      }
      player.position.add(direction * movementSpeed * dt);
      _keepPlayerOnScreen();
    }
    if (!battleOver) {
      for (final fighter in [...allies, ...devilTeam]) {
        _updateAi(fighter, dt);
      }
      _separateTeam(allies, dt);
      _separateTeam(devilTeam.toList(), dt);
    }
  }

  void _placeFighters() {
    player.position.setValues(size.x * 0.32, size.y * 0.62);
    enemy.position.setValues(size.x * 0.76, size.y * 0.62);
    player.scale.x = 1;
    enemy.scale.x = -1;
    for (var i = 0; i < allies.length; i++) {
      final lane = [0.24, 0.43, 0.82][i % 3];
      allies[i].position.setValues(size.x * 0.40, size.y * lane);
      additionalEnemies[i].position.setValues(size.x * 0.76, size.y * lane);
      allies[i].scale.x = 1;
      additionalEnemies[i].scale.x = -1;
    }
  }

  void restartBattle() {
    if (!_ready || _leaving) return;
    stopMovement();
    for (final fighter in fighters) {
      fighter.restoreHealth();
    }
    _aiTargets.clear();
    _aiTargets[enemy] = player;
    for (final fighter in _aiCooldowns.keys) {
      _aiCooldowns[fighter] = 0.8;
    }
    player.cancelUltimate();
    ultimateCooldownRemaining = 0;
    _updateUltimateButton();
    resumeBattleAudio();
    _placeFighters();
    for (final fighter in fighters) {
      _keepFighterOnScreen(fighter);
    }
    if (_retryShown) retryButton.removeFromParent();
    _retryShown = false;
  }

  void _updateAi(KingdomFighter fighter, double dt) {
    if (fighter.isDefeated) return;
    final cooldown = math.max(0.0, (_aiCooldowns[fighter] ?? 0) - dt);
    _aiCooldowns[fighter] = cooldown;
    fighter.isMoving = false;
    if (fighter.isAttacking || fighter.isHurt) return;
    // Commit to a living opponent so nearby pairs do not continually swap
    // targets and converge on the same fighter in the middle of the screen.
    var target = _aiTargets[fighter];
    if (target == null || target.isDefeated) {
      final opponents =
          (fighter.isDevil ? angelTeam : devilTeam)
              .where((candidate) => !candidate.isDefeated)
              .toList()
            ..sort(
              (a, b) => fighter.position
                  .distanceToSquared(a.position)
                  .compareTo(fighter.position.distanceToSquared(b.position)),
            );
      if (opponents.isEmpty) return;
      target = opponents.first;
    }
    _aiTargets[fighter] = target;
    final delta = target.position - fighter.position;
    // The isolated practice duel retains its guard distance.
    if (reinforcements == 0 && delta.length > player.height * 2) return;
    if (delta.x.abs() > 1) fighter.scale.x = delta.x < 0 ? -1 : 1;
    final stopDistance = (fighter.height + target.height) * 0.31;
    if (delta.length > stopDistance || delta.y.abs() > fighter.height * 0.35) {
      fighter.isMoving = true;
      final travel = math.min(
        movementSpeed * 0.48 * math.min(dt, 0.1),
        delta.length,
      );
      fighter.position.add(delta.normalized() * travel);
      _keepFighterOnScreen(fighter);
    } else if (cooldown <= 0 && fighter.startAttack()) {
      _aiCooldowns[fighter] = fighter.isDevil ? 1.2 : 1.05;
    }
  }

  void _separateTeam(List<KingdomFighter> team, double dt) {
    for (var i = 0; i < team.length; i++) {
      for (var j = i + 1; j < team.length; j++) {
        final a = team[i], b = team[j];
        if (a.isDefeated || b.isDefeated) continue;
        final delta = a.position - b.position;
        final distance = delta.length;
        final spacing = (a.width + b.width) * 0.24;
        if (distance >= spacing) continue;
        final push =
            (distance > 0.01 ? delta / distance : Vector2(0, 1)) *
            math.min((spacing - distance) / 2, movementSpeed * dt * 0.2);
        a.position.add(push);
        b.position.sub(push);
        _keepFighterOnScreen(a);
        _keepFighterOnScreen(b);
      }
    }
  }

  void _strike(KingdomFighter attacker, KingdomFighter target, int damage) {
    if (_leaving || battleOver || attacker.isDefeated || target.isDefeated) {
      return;
    }
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
    for (final fighter in fighters) {
      fighter.isMoving = false;
      fighter.cancelAttack();
    }
    unawaited(_swordSound.stop());
    unawaited(_enemySound.stop());
    _ambiencePlaying = false;
    unawaited(_ambienceSound.stop());
  }

  @override
  void onRemove() {
    disposeAudio();
    super.onRemove();
  }

  void disposeAudio() {
    unawaited(_swordSound.dispose());
    unawaited(_enemySound.dispose());
    unawaited(_ambienceSound.dispose());
  }

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
  AngelPlayer(super.sheet, super.damageSprite, this.ultimateSheet)
    : super(isDevil: false) {
    Sprite pose(Rect crop) => Sprite(
      ultimateSheet.image,
      srcPosition: Vector2(
        crop.left / 2752 * ultimateSheet.image.width,
        crop.top / 1536 * ultimateSheet.image.height,
      ),
      srcSize: Vector2(
        crop.width / 2752 * ultimateSheet.image.width,
        crop.height / 1536 * ultimateSheet.image.height,
      ),
    );
    _ultimateFrames = [
      pose(const Rect.fromLTRB(530, 1060, 950, 1500)),
      pose(const Rect.fromLTRB(976, 1060, 1380, 1500)),
      pose(const Rect.fromLTRB(1380, 1020, 1845, 1500)),
    ];
  }
  final Sprite ultimateSheet;
  late final List<Sprite> _ultimateFrames;
  VoidCallback? onUltimateStrike;
  static const ultimateDuration = 1.4;
  double _ultimateElapsed = ultimateDuration;
  bool get isUltimateActive =>
      !isDefeated && _ultimateElapsed < ultimateDuration;
  void startUltimate() {
    cancelAttack();
    isMoving = false;
    _ultimateElapsed = 0;
  }

  void cancelUltimate() => _ultimateElapsed = ultimateDuration;
  @override
  bool startAttack() => !isUltimateActive && super.startAttack();
  @override
  void update(double dt) {
    super.update(dt);
    final before = _ultimateElapsed;
    _ultimateElapsed = math.min(ultimateDuration, _ultimateElapsed + dt);
    if (!isDefeated && before < 0.45 && _ultimateElapsed >= 0.45) {
      onUltimateStrike?.call();
    }
  }

  @override
  Sprite get currentSprite => isUltimateActive
      ? _ultimateFrames[_ultimateElapsed < 0.3
            ? 0
            : _ultimateElapsed < 0.65
            ? 1
            : 2]
      : super.currentSprite;
  @override
  void render(Canvas canvas) {
    if (isUltimateActive) {
      final t = _ultimateElapsed / ultimateDuration;
      final alpha = math.sin(t * math.pi);
      final center = Offset(width / 2, height * 0.65);
      final radius = height * 2 * t;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Color.fromRGBO(255, 213, 95, alpha * 0.12),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Color.fromRGBO(255, 235, 156, alpha * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4 + t;
        final p =
            center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.65;
        final paint = Paint()
          ..color = Color.fromRGBO(160, 255, 186, alpha)
          ..strokeWidth = 3;
        canvas.drawLine(p - const Offset(5, 0), p + const Offset(5, 0), paint);
        canvas.drawLine(p - const Offset(0, 5), p + const Offset(0, 5), paint);
      }
    }
    super.render(canvas);
  }

  @override
  void onRemove() {
    ultimateSheet.image.dispose();
    super.onRemove();
  }

  static const attackDuration = KingdomFighter.attackDuration;
}

class DevilEnemy extends KingdomFighter {
  DevilEnemy(super.sheet, super.damageSprite) : super(isDevil: true);
}

class KingdomFighter extends PositionComponent {
  KingdomFighter(this._sheet, this.damageSprite, {required this.isDevil})
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
  final Sprite damageSprite;
  final bool isDevil;
  VoidCallback? onAttack;
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
  static const hurtDuration = 0.3;
  double _attackElapsed = 1;
  double get swingDuration => isDevil ? 0.65 : attackDuration;
  bool get isAttacking => _attackElapsed < swingDuration;
  double get attackProgress => (_attackElapsed / swingDuration).clamp(0.0, 1.0);

  bool startAttack() {
    if (isAttacking || isDefeated || isHurt) return false;
    _attackElapsed = 0;
    onAttack?.call();
    return true;
  }

  void cancelAttack() => _attackElapsed = swingDuration;

  void takeDamage(int damage) {
    if (damage <= 0 || isDefeated) return;
    _health = math.max(0, _health - damage);
    _hurtTime = hurtDuration;
    isMoving = false;
    cancelAttack();
  }

  void restoreHealth() {
    _health = maxHealth;
    _hurtTime = 0;
    isMoving = false;
    cancelAttack();
  }

  void heal(int amount) {
    if (isDefeated || amount <= 0) return;
    _health = math.min(maxHealth, _health + amount);
    _hurtTime = 0;
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

  Sprite get currentSprite => isHurt
      ? damageSprite
      : isAttacking
      ? _attackFrames[attackProgress < 0.22
            ? 0
            : attackProgress < 0.58
            ? 1
            : 2]
      : isMoving
      ? _moving
      : _idle;

  @override
  void render(Canvas canvas) {
    canvas.save();
    final fallen = isDefeated && !isHurt;
    if (fallen) {
      canvas.translate(size.x / 2, size.y * 0.82);
      canvas.rotate(math.pi / 2);
      canvas.scale(0.8);
      canvas.translate(-size.x / 2, -size.y / 2);
    }
    final sprite = currentSprite;
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
    _paint.color = Color.fromRGBO(255, 255, 255, fallen ? 0.45 : 1);
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
    damageSprite.image.dispose();
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

  String label;
  bool enabled = true;
  TextComponent? _labelText;
  final VoidCallback onPressed;
  final bool circular;

  @override
  Future<void> onLoad() async {
    await add(
      _labelText = TextComponent(
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
  void update(double dt) {
    super.update(dt);
    _labelText?.text = label;
  }

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      Radius.circular(circular ? 54 : 10),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = enabled ? const Color(0xBD30263E) : const Color(0xDD252530),
    );
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
  void onTapUp(TapUpEvent event) {
    if (enabled) onPressed();
  }
}
