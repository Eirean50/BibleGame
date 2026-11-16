import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Era1Screen extends StatefulWidget {
  const Era1Screen({super.key});

  @override
  State<Era1Screen> createState() => _Era1ScreenState();
}

class _Era1ScreenState extends State<Era1Screen> with WidgetsBindingObserver {
  static const _displayChannel = MethodChannel('daloy/display');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enterFullscreen());
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (mounted) await _setFullscreen(true);
  }

  static Future<void> _setFullscreen(bool enabled) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Android 16+ ignores Flutter's legacy immersive system-UI flags.
        await _displayChannel.invokeMethod<void>('setFullscreen', enabled);
        return;
      } on MissingPluginException {
        // Also supports tests and an older host during hot reload.
      }
    }
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_enterFullscreen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_setFullscreen(false));
    unawaited(SystemChrome.setPreferredOrientations([]));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF211C26),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: GameWidget<Era1Game>.controlled(
              gameFactory: Era1Game.new,
              loadingBuilder: (context) => const Center(
                child: CircularProgressIndicator(color: Color(0xFFF4CB80)),
              ),
              errorBuilder: (context, error) {
                debugPrint('Era 1 asset loading failed: $error');
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Hindi ma-load ang tagpo. Bumalik at subukang muli.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFFE9BC)),
                    ),
                  ),
                );
              },
              overlayBuilderMap: {
                'dialogue': (context, game) => DialogueOverlay(game: game),
              },
              initialActiveOverlays: const ['dialogue'],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(8),
              child: IconButton.filled(
                tooltip: 'Bumalik sa menu',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xB3352631),
                  foregroundColor: const Color(0xFFFFEDCF),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The composition uses a 1024x572 stage, matching the supplied artwork.
// Cover the entire viewport uniformly; crop excess edges instead of letterboxing.
class Era1Game extends FlameGame {
  Era1Game({AssetBundle? assetBundle}) : _bundle = assetBundle ?? rootBundle;

  static const stageWidth = 1024.0;
  static const stageHeight = 572.0;
  static const dialogueSeconds = 5.0;
  static const lines = [
    DialogueLine('Datu', 'Maligayang pagdating sa ating Barangay!'),
    DialogueLine('Kawal', 'Handa kaming magsilbi, Datu.'),
    DialogueLine('Taganayon', 'Sariwa ang ating huli ngayong araw!'),
    DialogueLine('Datu', 'Sa pagtutulungan, uunlad ang ating pamayanan.'),
  ];

  final AssetBundle _bundle;
  final dialogue = ValueNotifier<DialogueLine>(lines.first);
  final stage = ClipComponent.rectangle(size: Vector2(stageWidth, stageHeight));
  final actors = <IdleSprite>[];
  final _ownedImages = <ui.Image>[];
  late final IdleSprite sea;
  late final IdleSprite sailboat;
  double _elapsed = 0;
  int _lineIndex = 0;
  bool _ready = false;
  bool _disposed = false;

  static double dialogueHeight(double height) => math.min(height * 0.24, 104.0);

  @override
  Color backgroundColor() => const Color(0xFF211C26);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final skyImage = await _loadImage('bg_sky.png', targetWidth: 1024);
    final seaImage = await _loadImage('bg_sea.png');
    final groundImage = await _loadImage(
      'bg_ground.png',
      targetWidth: 1024,
      checkerMin: 175,
    );
    final atlas = await _loadImage('era1_spritesheet.png', checkerMin: 75);

    // The supplied sky and sea files have opaque checkerboard margins.
    // Sample only their painted regions; the foreground is alpha-masked below.
    final sky = SpriteComponent(
      sprite: Sprite(
        skyImage,
        srcSize: Vector2(skyImage.width.toDouble(), skyImage.height * 0.5),
      ),
      size: Vector2(stageWidth, 286),
    );
    sea = IdleSprite(
      sprite: _region(
        seaImage,
        const Rect.fromLTWH(0, 212, 1024, 290),
        referenceWidth: 1024,
        referenceHeight: 572,
      ),
      position: Vector2(-12, 280),
      size: Vector2(stageWidth + 24, stageHeight - 280),
      anchor: Anchor.topLeft,
      horizontalAmplitude: 6,
      verticalAmplitude: 0,
      speed: 0.45,
    );
    final ground = SpriteComponent(
      sprite: Sprite(groundImage),
      size: Vector2(stageWidth, stageHeight),
    );
    await stage.addAll([sky, sea, ground]);

    // Rectangles below were measured from the supplied 608x208 sprite sheet.
    // Actor positions are their feet (bottom-center) on the beach or water.
    void place(
      String name,
      Rect crop,
      double x,
      double y,
      double height, {
      bool alive = false,
      double bob = 1.5,
      double speed = 1.8,
    }) {
      final sprite = _region(atlas, crop);
      final component = IdleSprite(
        sprite: sprite,
        position: Vector2(x, y),
        size: Vector2(height * crop.width / crop.height, height),
        verticalAmplitude: alive ? bob : 0,
        speed: speed,
        phase: alive ? actors.length * 2.399 : 0,
        breathScale: alive && name != 'sailboat' ? 0.008 : 0,
      );
      if (alive) actors.add(component);
      if (name == 'sailboat') sailboat = component;
      stage.add(component);
    }

    place('house-left', const Rect.fromLTWH(0, 0, 106, 113), 520, 350, 157);
    place('house-right', const Rect.fromLTWH(106, 0, 128, 115), 700, 391, 180);
    place('market', const Rect.fromLTWH(240, 35, 90, 70), 437, 384, 72);
    place(
      'sailboat',
      const Rect.fromLTWH(351, 0, 104, 88),
      167,
      370,
      176,
      alive: true,
      bob: 3,
      speed: 0.9,
    );
    place('canoe', const Rect.fromLTWH(455, 37, 111, 56), 345, 467, 76);
    place(
      'fisher',
      const Rect.fromLTWH(362, 102, 42, 57),
      334,
      425,
      60,
      alive: true,
      speed: 1.65,
    );
    place(
      'carrier',
      const Rect.fromLTWH(496, 116, 40, 56),
      483,
      423,
      61,
      alive: true,
      speed: 1.45,
    );
    place(
      'villager-left',
      const Rect.fromLTWH(229, 143, 40, 65),
      536,
      480,
      65,
      alive: true,
      speed: 1.7,
    );
    place(
      'villager-right',
      const Rect.fromLTWH(308, 142, 43, 66),
      622,
      480,
      65,
      alive: true,
      speed: 1.95,
    );
    place(
      'fire',
      const Rect.fromLTWH(269, 173, 38, 35),
      581,
      485,
      40,
      alive: true,
      bob: 0.6,
      speed: 5.5,
    );
    place(
      'basket-villager',
      const Rect.fromLTWH(404, 137, 41, 65),
      680,
      449,
      65,
      alive: true,
      speed: 1.55,
    );
    place(
      'datu',
      const Rect.fromLTWH(8, 122, 49, 86),
      788,
      460,
      86,
      alive: true,
      bob: 1.2,
      speed: 1.4,
    );
    place(
      'warrior-left',
      const Rect.fromLTWH(115, 128, 50, 80),
      737,
      478,
      80,
      alive: true,
      speed: 1.6,
    );
    place(
      'warrior-right',
      const Rect.fromLTWH(166, 128, 52, 80),
      843,
      478,
      80,
      alive: true,
      speed: 1.8,
    );
    place(
      'pig',
      const Rect.fromLTWH(353, 175, 41, 30),
      660,
      514,
      29,
      alive: true,
      bob: 1,
      speed: 2.1,
    );
    place(
      'chicken-left',
      const Rect.fromLTWH(460, 174, 28, 31),
      712,
      525,
      26,
      alive: true,
      bob: 1,
      speed: 2.7,
    );
    place(
      'chicken-right',
      const Rect.fromLTWH(508, 174, 30, 31),
      760,
      528,
      26,
      alive: true,
      bob: 1.2,
      speed: 2.4,
    );
    place(
      'crab-left',
      const Rect.fromLTWH(543, 179, 29, 29),
      393,
      502,
      21,
      alive: true,
      bob: 1,
      speed: 2.2,
    );
    place(
      'crab-right',
      const Rect.fromLTWH(579, 179, 28, 29),
      480,
      537,
      22,
      alive: true,
      bob: 1,
      speed: 2.6,
    );

    await add(stage);
    _ready = true;
    _layoutStage();
  }

  Future<ui.Image> _loadImage(
    String name, {
    int? targetWidth,
    int? checkerMin,
  }) async {
    try {
      final data = await _bundle.load('assets/images/$name');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: targetWidth,
      );
      ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (checkerMin != null) {
        final original = image;
        try {
          image = await removeCheckerboard(original, minimumGray: checkerMin);
        } finally {
          original.dispose();
        }
      }
      if (_disposed) {
        image.dispose();
        throw StateError('Scene was closed while loading.');
      }
      _ownedImages.add(image);
      return image;
    } catch (error) {
      throw StateError('Cannot load assets/images/$name: $error');
    }
  }

  Sprite _region(
    ui.Image image,
    Rect rect, {
    double referenceWidth = 608,
    double referenceHeight = 208,
  }) {
    if (rect.left < 0 ||
        rect.top < 0 ||
        rect.right > referenceWidth ||
        rect.bottom > referenceHeight) {
      throw ArgumentError(
        'Sprite rectangle is outside the source sheet: $rect',
      );
    }
    final sx = image.width / referenceWidth;
    final sy = image.height / referenceHeight;
    return Sprite(
      image,
      srcPosition: Vector2(rect.left * sx, rect.top * sy),
      srcSize: Vector2(rect.width * sx, rect.height * sy),
    );
  }

  void _layoutStage() {
    if (!_ready || size.x <= 0 || size.y <= 0) return;
    final zoom = math.max(size.x / stageWidth, size.y / stageHeight);
    stage.scale.setAll(zoom);
    stage.position.setValues(
      (size.x - stageWidth * zoom) / 2,
      // Favor the village and shoreline when a wide phone crops the sky.
      size.y - stageHeight * zoom,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutStage();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_ready || _disposed) return;
    _elapsed += dt;
    final next = (_elapsed / dialogueSeconds).floor() % lines.length;
    if (next != _lineIndex) {
      _lineIndex = next;
      dialogue.value = lines[next];
    }
  }

  @override
  void onDispose() {
    _disposed = true;
    dialogue.dispose();
    for (final image in _ownedImages) {
      image.dispose();
    }
    _ownedImages.clear();
    super.onDispose();
  }
}

/// Absolute sine offsets avoid drift and use different phases for each actor.
class IdleSprite extends SpriteComponent {
  IdleSprite({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    Anchor anchor = Anchor.bottomCenter,
    this.horizontalAmplitude = 0,
    this.verticalAmplitude = 1.5,
    this.speed = 1.8,
    this.phase = 0,
    this.breathScale = 0,
  }) : basePosition = position.clone(),
       super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: anchor,
         paint: Paint()..filterQuality = FilterQuality.none,
       );

  final Vector2 basePosition;
  final double horizontalAmplitude;
  final double verticalAmplitude;
  final double speed;
  final double phase;
  final double breathScale;
  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final wave = math.sin(_time * speed + phase);
    position.setValues(
      basePosition.x + wave * horizontalAmplitude,
      basePosition.y + wave * verticalAmplitude,
    );
    scale.y = 1 + wave * breathScale;
  }
}

class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker;
  final String text;
}

class DialogueOverlay extends StatelessWidget {
  const DialogueOverlay({required this.game, super.key});
  final Era1Game game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: Era1Game.dialogueHeight(constraints.maxHeight),
              width: math.min(constraints.maxWidth, 800),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xD9352631),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5B96D), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 16),
                  ],
                ),
                child: SingleChildScrollView(
                  child: ValueListenableBuilder<DialogueLine>(
                    valueListenable: game.dialogue,
                    builder: (context, line, child) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NAG-UUSAP',
                          style: TextStyle(
                            color: Color(0xFFE5B96D),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Semantics(
                            key: ValueKey(line),
                            liveRegion: true,
                            child: Text(
                              '${line.speaker}: “${line.text}”',
                              style: const TextStyle(
                                color: Color(0xFFFFEDCF),
                                fontSize: 17,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The supplied PNGs have an opaque gray checkerboard. Remove only neutral
/// atlas background pixels reachable from an edge, preserving enclosed gray
/// details (shields, clothing). The beach's pale checkerboard also occurs inside
/// the foam, so its neutral pale pixels are keyed throughout that layer.
/// Already-transparent replacements pass through.
/// This changes decoded pixels in memory; the original asset files stay intact.
Future<ui.Image> removeCheckerboard(
  ui.Image source, {
  required int minimumGray,
}) async {
  final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('Could not read image pixels.');
  final pixels = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  final width = source.width;
  final height = source.height;
  // A genuine alpha channel should never be color-keyed.
  for (var p = 3; p < pixels.length; p += 4) {
    if (pixels[p] < 255) return source.clone();
  }
  final queue = Int32List(width * height);
  var head = 0;
  var tail = 0;
  void visit(int pixel) {
    final offset = pixel * 4;
    if (pixels[offset + 3] == 0) return;
    final low = math.min(
      pixels[offset],
      math.min(pixels[offset + 1], pixels[offset + 2]),
    );
    final high = math.max(
      pixels[offset],
      math.max(pixels[offset + 1], pixels[offset + 2]),
    );
    if (low < minimumGray || high - low > 18) return;
    // The atlas checkerboard is mid-gray; preserve pale animal feathers.
    if (minimumGray < 100 && high > 195) return;
    pixels[offset] = pixels[offset + 1] = pixels[offset + 2] =
        pixels[offset + 3] = 0;
    queue[tail++] = pixel;
  }

  for (var x = 0; x < width; x++) {
    visit(x);
    visit((height - 1) * width + x);
  }
  for (var y = 0; y < height; y++) {
    visit(y * width);
    visit(y * width + width - 1);
  }
  if (minimumGray >= 175) {
    for (var p = 0; p < width * height; p++) {
      visit(p);
    }
  }
  while (head < tail) {
    final p = queue[head++];
    final x = p % width;
    if (x > 0) visit(p - 1);
    if (x + 1 < width) visit(p + 1);
    if (p >= width) visit(p - width);
    if (p + width < width * height) visit(p + width);
  }
  final result = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    result.complete,
  );
  return result.future;
}
