import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'sky_motion.dart';
import 'flying_angel.dart';
import 'ground_art.dart';
import 'flying_bird.dart';
import 'keyed_art.dart';
import 'land_animal.dart';
import 'human_character.dart';

enum CreationStage {
  light,
  sky,
  waters,
  land,
  vegetation,
  heavens,
  seaLife,
  animals,
  people,
  angels,
}

/// Pixel scenery with sky/sea artwork and independent OpacityEffect targets.
class CreationBackdrop extends PositionComponent {
  CreationBackdrop({bool humansAlreadyFormed = false})
    : layers = {
        for (final stage in CreationStage.values)
          stage: CreationLayer(stage, humansAlreadyFormed: humansAlreadyFormed),
      };

  final Map<CreationStage, CreationLayer> layers;
  final revealed = <CreationStage>{};

  @override
  Future<void> onLoad() async => addAll(layers.values);

  @override
  void renderTree(Canvas canvas) {
    canvas.save();
    canvas.scale(size.x / 320, size.y / 180);
    super.renderTree(canvas);
    canvas.restore();
  }
}

class CreationLayer extends PositionComponent with HasPaint {
  CreationLayer(this.stage, {this.humansAlreadyFormed = false}) {
    opacity = 0;
  }
  final CreationStage stage;
  final bool humansAlreadyFormed;
  SkyMotion? _sky;
  Sprite? _sea;
  Sprite? _ground;
  Sprite? _birdSheet;
  Sprite? _lionSheet;
  Sprite? _deerSheet;
  Sprite? _humanSheet;
  final angels = <FlyingAngel>[];
  final birds = <FlyingBird>[];
  final animals = <LandAnimal>[];
  HumanCreation? humanCreation;
  double _waterTime = 0;

  @override
  Future<void> onLoad() async {
    if (stage == CreationStage.sky) {
      final sprite = await Sprite.load('bg_sky.png');
      _sky = SkyMotion(sprite.image);
      paint.filterQuality = FilterQuality.none;
    } else if (stage == CreationStage.waters) {
      final sprite = await Sprite.load('bg_sea.png');
      // Use only the painted water between the checkerboard margins.
      // Coordinates are relative to the supplied 1024x572 artwork.
      final scaleX = sprite.image.width / 1024;
      final scaleY = sprite.image.height / 572;
      sprite.srcSize = Vector2(1024 * scaleX, 290 * scaleY);
      sprite.srcPosition = Vector2(0, 212 * scaleY);
      _sea = sprite;
      paint.filterQuality = FilterQuality.none;
    } else if (stage == CreationStage.land) {
      _ground = await loadGroundArt();
      paint.filterQuality = FilterQuality.none;
    } else if (stage == CreationStage.angels) {
      final sheet = await Sprite.load('AngelsSpriteSheetNew.png');
      // Eight 64x64 cells: the first four form the front-facing wing cycle.
      final frameWidth = sheet.image.width / 8;
      final animation = SpriteAnimation.spriteList([
        for (var frame = 0; frame < 4; frame++)
          Sprite(
            sheet.image,
            srcPosition: Vector2(frame * frameWidth, 0),
            srcSize: Vector2(frameWidth, sheet.image.height.toDouble()),
          ),
      ], stepTime: 0.18);
      for (var i = 0; i < 3; i++) {
        angels.add(
          FlyingAngel(
            animation: animation,
            position: Vector2(88 + i * 64.0, i == 1 ? 28 : 21),
            phase: i * 2.1,
          ),
        );
      }
      await addAll(angels);
    } else if (stage == CreationStage.seaLife) {
      _birdSheet = await loadKeyedArt('Bird.png');
      final animation = birdWingAnimation(_birdSheet!.image);
      for (var i = 0; i < 2; i++) {
        birds.add(
          FlyingBird(
            animation: animation,
            startX: 40 + i * 200.0,
            altitude: 48 + (i % 3) * 13.0,
            speed: i.isEven ? 13 + i * 2.0 : -16 - i * 2.0,
            phase: i * 1.7,
            width: 18 + (i % 3) * 3.0,
          ),
        );
      }
      await addAll(birds);
    } else if (stage == CreationStage.animals) {
      _lionSheet = await loadKeyedArt('lion.png');
      _deerSheet = await loadKeyedArt('Deer.png');
      animals.addAll([
        LandAnimal(
          animation: lionAnimation(_lionSheet!.image),
          position: Vector2(78, 158),
          frameHeight: 36,
        ),
        LandAnimal(
          animation: deerAnimation(_deerSheet!.image),
          position: Vector2(220, 154),
          frameHeight: 40,
          wanderDistance: 22,
        ),
      ]);
      await addAll(animals);
    } else if (stage == CreationStage.people) {
      _humanSheet = await loadKeyedArt('human.png');
      humanCreation = HumanCreation(
        image: _humanSheet!.image,
        position: Vector2(153, 161),
        alreadyFormed: humansAlreadyFormed,
      );
      await add(humanCreation!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final angel in angels) {
      angel.opacity = opacity;
    }
    for (final bird in birds) {
      bird.opacity = opacity;
    }
    for (final animal in animals) {
      animal.opacity = opacity;
    }
    humanCreation?.opacity = opacity;
    if (opacity > 0) {
      _sky?.update(dt);
      if (stage == CreationStage.waters) _waterTime += dt;
    }
  }

  @override
  void onRemove() {
    _sky?.dispose();
    _sky = null;
    _ground?.image.dispose();
    _ground = null;
    _birdSheet?.image.dispose();
    _birdSheet = null;
    _lionSheet?.image.dispose();
    _lionSheet = null;
    _deerSheet?.image.dispose();
    _deerSheet = null;
    _humanSheet?.image.dispose();
    _humanSheet = null;
    super.onRemove();
  }

  void _renderSea(Canvas canvas) {
    final sea = _sea;
    if (sea == null || opacity <= 0) return;
    const strips = 34;
    final source = sea.src;

    // Thin water bands drift at different phases, giving the painted waves
    // a gentle ripple. Extra width covers both edges throughout the motion.
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 112, 320, 68));
    double sampleDepth(double depth) =>
        (depth +
                math.sin(math.pi * depth) *
                    math.sin(_waterTime * 1.1 - depth * 6) *
                    0.008)
            .clamp(0.0, 1.0);

    for (var row = 0; row < strips; row++) {
      final depth = row / strips;
      final drift =
          math.sin(_waterTime * 0.8 - depth * 7) * (0.3 + depth * 1.7);
      final top = sampleDepth(depth);
      final bottom = sampleDepth((row + 1) / strips);
      canvas.drawImageRect(
        sea.image,
        Rect.fromLTRB(
          source.left,
          source.top + source.height * top,
          source.right,
          source.top + source.height * bottom,
        ),
        Rect.fromLTWH(-4 + drift, 112 + row * 2.0, 328, 2),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    void pixel(double x, double y, double w, double h, int color) {
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()
          ..isAntiAlias = false
          ..color = Color(color).withValues(alpha: opacity),
      );
    }

    switch (stage) {
      case CreationStage.light:
        pixel(0, 0, 320, 180, 0xFF46475E);
        pixel(0, 76, 320, 104, 0xFF9B947F);
        pixel(0, 105, 320, 75, 0xFFD6BD89);
      case CreationStage.sky:
        _sky?.render(canvas, opacity);
      case CreationStage.waters:
        _renderSea(canvas);
      case CreationStage.land:
        _ground?.render(
          canvas,
          position: Vector2(0, 40),
          size: Vector2(320, 140),
          overridePaint: paint,
        );
      case CreationStage.vegetation:
        // Ground.png already includes the trees and foliage.
        break;
      case CreationStage.angels:
        // Animated child components render above the other scenery layers.
        break;
      case CreationStage.heavens:
        pixel(54, 17, 22, 22, 0xFFFFDA83);
        pixel(50, 21, 30, 14, 0xFFFFDA83);
        pixel(263, 17, 12, 16, 0xFFE5E5C9);
        pixel(269, 15, 9, 12, 0xFF293D68);
        for (var i = 0; i < 17; i++) {
          pixel(
            150 + (i * 31 % 160).toDouble(),
            7 + (i * 13 % 36).toDouble(),
            2,
            2,
            0xFFFFE6B7,
          );
        }
      case CreationStage.seaLife:
        for (final x in [106.0, 160.0, 211.0]) {
          pixel(x, 130, 9, 3, 0xFFD5B572);
          pixel(x + 9, 128, 3, 7, 0xFFD5B572);
        }
      case CreationStage.animals:
        // Lion and deer are animated child components on the foreground.
        break;
      case CreationStage.people:
        // Dust-to-human formation renders as a child component.
        break;
    }
  }
}
