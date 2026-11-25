import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// A full-screen defeat view that intercepts input over the battle controls.
class BattleLossScreen extends PositionComponent
    with TapCallbacks, DragCallbacks {
  BattleLossScreen({required this.retryButton, this.onRevealed})
    : super(priority: 10000) {
    add(retryButton);
  }

  static const verse =
      'Therefore rejoice, you heavens and you who dwell in them! '
      'But woe to the earth and the sea, because the devil has gone down to you! '
      'He is filled with fury, because he knows that his time is short.”';
  static const reference = '-Revelations 12:12';

  final PositionComponent retryButton;
  final VoidCallback? onRevealed;
  static const revealDelay = 0.8;
  static const fadeDuration = 2.8;
  double _elapsed = 0;
  bool get isFullyVisible => _elapsed >= revealDelay + fadeDuration;
  double get revealOpacity {
    final progress = ((_elapsed - revealDelay) / fadeDuration).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(progress);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final wasVisible = isFullyVisible;
    _elapsed = math.min(revealDelay + fadeDuration, _elapsed + dt);
    if (!wasVisible && isFullyVisible) onRevealed?.call();
  }

  @override
  void renderTree(Canvas canvas) {
    final opacity = revealOpacity;
    if (opacity <= 0) return;
    if (opacity >= 1) {
      super.renderTree(canvas);
      return;
    }
    // Fade the background, verse and retry button together as a single layer.
    canvas.saveLayer(
      size.toRect(),
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    super.renderTree(canvas);
    canvas.restore();
  }

  final _title = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  final _verse = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  final _reference = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  Rect contentBounds = Rect.zero;
  double _gap = 16;

  void resize(Vector2 viewport) {
    size.setFrom(viewport);
    if (size.x <= 0 || size.y <= 0) return;
    final textWidth = math.max(1.0, math.min(700.0, size.x - 48));
    var scale = 1.0;
    double contentHeight;
    do {
      _gap = 16 * scale;
      _layoutText(
        _title,
        'YOU LOST',
        34 * scale,
        textWidth,
        const Color(0xFFFFB4A0),
        bold: true,
      );
      _layoutText(
        _verse,
        verse,
        21 * scale,
        textWidth,
        const Color(0xFFFFEED6),
      );
      _layoutText(
        _reference,
        reference,
        16 * scale,
        textWidth,
        const Color(0xFFE1BB7B),
      );
      contentHeight =
          _title.height +
          _verse.height +
          _reference.height +
          _gap * 4 +
          retryButton.height;
      if (contentHeight <= size.y - 40 || scale <= 0.45) break;
      scale *= 0.92;
    } while (true);
    contentBounds = Rect.fromLTWH(
      (size.x - textWidth) / 2,
      (size.y - contentHeight) / 2,
      textWidth,
      contentHeight,
    );
    retryButton.position.setValues(
      size.x / 2,
      contentBounds.bottom - retryButton.height / 2,
    );
  }

  void _layoutText(
    TextPainter painter,
    String text,
    double fontSize,
    double width,
    Color color, {
    bool bold = false,
  }) {
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        height: 1.4,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        letterSpacing: bold ? 3 : 0,
      ),
    );
    painter.layout(minWidth: width, maxWidth: width);
  }

  @override
  void render(Canvas canvas) {
    final bounds = size.toRect();
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF382438), Color(0xFF110F1D)],
          radius: 0.9,
        ).createShader(bounds),
    );
    final linePaint = Paint()
      ..color = const Color(0xFF98714F)
      ..strokeWidth = 1;
    final lineY = contentBounds.top + _title.height + _gap / 2;
    canvas.drawLine(
      Offset(size.x / 2 - 36, lineY),
      Offset(size.x / 2 + 36, lineY),
      linePaint,
    );
    var y = contentBounds.top;
    _title.paint(canvas, Offset(contentBounds.left, y));
    y += _title.height + _gap;
    _verse.paint(canvas, Offset(contentBounds.left, y));
    y += _verse.height + _gap;
    _reference.paint(canvas, Offset(contentBounds.left, y));
  }

  @override
  void onTapDown(TapDownEvent event) {}
  @override
  void onTapUp(TapUpEvent event) {}
  @override
  void onDragUpdate(DragUpdateEvent event) {}

  @override
  void onRemove() {
    _title.dispose();
    _verse.dispose();
    _reference.dispose();
    super.onRemove();
  }
}
