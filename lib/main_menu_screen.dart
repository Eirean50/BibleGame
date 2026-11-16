import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'keyed_art.dart';
import 'story_screen.dart';

const _gold = Color(0xFFE7C78D);
const _ink = Color(0xFF101B32);

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 900;
          final compact = bounds.maxHeight < 500;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                left: wide ? bounds.maxWidth * 0.22 : 0,
                bottom: wide ? 0 : bounds.maxHeight * (compact ? 0.28 : 0.54),
                child: const HeavenBackdrop(),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: wide ? Alignment.centerLeft : Alignment.topCenter,
                    end: wide ? Alignment.centerRight : Alignment.bottomCenter,
                    colors: wide
                        ? const [
                            _ink,
                            _ink,
                            Color(0xE6101B32),
                            Color(0x18101B32),
                            Color(0x00101B32),
                          ]
                        : const [
                            Color(0x15101B32),
                            Color(0x55101B32),
                            _ink,
                            _ink,
                          ],
                    stops: wide
                        ? const [0, 0.2, 0.34, 0.59, 1]
                        : compact
                        ? const [0, 0.32, 0.66, 1]
                        : const [0, 0.16, 0.46, 1],
                  ),
                ),
              ),
              // A restrained gold frame gives the artwork a game-cover finish.
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 24 : 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, safe) => SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 64 : 28,
                      vertical: compact ? 16 : 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0,
                          safe.maxHeight - (compact ? 32 : 64),
                        ),
                      ),
                      child: Align(
                        alignment: wide
                            ? Alignment.centerLeft
                            : Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: wide || compact ? 0 : safe.maxHeight * 0.28,
                          ),
                          child: SizedBox(
                            width: wide
                                ? math.min(420, bounds.maxWidth * 0.34)
                                : 380,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: wide
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'IN THE BEGINNING',
                                  textAlign: wide
                                      ? TextAlign.left
                                      : TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: _gold,
                                    fontSize: 11,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'OLD TESTAMENT',
                                  textAlign: wide
                                      ? TextAlign.left
                                      : TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: compact
                                        ? 30
                                        : wide
                                        ? 58
                                        : 40,
                                    height: 1.05,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFFF0CF),
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x99000000),
                                        blurRadius: 16,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(width: 56, height: 2, color: _gold),
                                const SizedBox(height: 18),
                                Text(
                                  'Isang paglalakbay sa Lumang Tipan',
                                  textAlign: wide
                                      ? TextAlign.left
                                      : TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Color(0xFFC5CBD5),
                                  ),
                                ),
                                SizedBox(height: compact ? 20 : 32),
                                SizedBox(
                                  width: 260,
                                  child: FilledButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (context) =>
                                            const StoryScreen(),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 28,
                                    ),
                                    label: const Text('Play'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _gold,
                                      foregroundColor: _ink,
                                      minimumSize: const Size(0, 58),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFFFE7B8),
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
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Both artwork and dove share the same cover transform on every screen size.
class HeavenBackdrop extends StatelessWidget {
  const HeavenBackdrop({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 1678,
          height: 937,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/God-background.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  excludeFromSemantics: true,
                ),
              ),
              const Positioned(
                left: 1678 * 0.43,
                top: 937 * 0.08,
                width: 1678 * 0.14,
                height: 937 * 0.29,
                child: HolySpiritEmblem(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Display one fixed pose from the supplied 4x2 dove sheet.
class HolySpiritEmblem extends StatefulWidget {
  const HolySpiritEmblem({super.key});

  @override
  State<HolySpiritEmblem> createState() => _HolySpiritEmblemState();
}

class _HolySpiritEmblemState extends State<HolySpiritEmblem> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final sprite = await loadKeyedArt('holyspirit.png');
    if (!mounted) {
      sprite.image.dispose();
      return;
    }
    setState(() => _image = sprite.image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 116,
      height: 118,
      child: CustomPaint(painter: _DovePainter(_image)),
    ),
  );
}

class _DovePainter extends CustomPainter {
  _DovePainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final sheet = image;
    if (sheet == null) return;
    const frame = 2; // Wings spread, held still.
    final width = sheet.width / 4;
    final height = sheet.height / 2;
    final source = Rect.fromLTWH(
      (frame % 4) * width,
      (frame ~/ 4) * height,
      width,
      height,
    );
    canvas.drawImageRect(
      sheet,
      source,
      Rect.fromLTWH(0, 0, size.width, size.height - 8),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_DovePainter oldDelegate) => oldDelegate.image != image;
}
