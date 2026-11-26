import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// Full-screen input surface; children render the scene and the RPG dialogue.
abstract class NarratedScene extends PositionComponent with TapCallbacks {
  NarratedScene({
    required this.script,
    required this.onFinished,
    this.onTextIndexChanged,
    required this.heading,
    required this.endHint,
    this.fixedPanelHeight = false,
  }) : assert(script.isNotEmpty);
  final List<String> script;
  final String heading;
  final String endHint;
  final bool fixedPanelHeight;
  bool get canFinish => true;
  bool get canAdvance => true;
  bool get isNarrationVisible => true;
  String get waitingHint => 'REVEALING THE GARDEN...';

  final VoidCallback onFinished;
  final ValueChanged<int>? onTextIndexChanged;
  static const secondsPerCharacter = 0.035;
  static const _gold = Color(0xFFE8C681);
  PositionComponent get backdrop;
  final dialoguePanel = RectangleComponent(
    paint: Paint()..color = const Color(0xDD101426),
    priority: 10,
  );
  final _border = RectangleComponent(
    paint: Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
    priority: 11,
  );
  late final _label = TextComponent(
    text: heading,
    textRenderer: TextPaint(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: _gold,
      ),
    ),
    priority: 12,
  );
  final _hint = TextComponent(
    text: 'TAP TO REVEAL',
    textRenderer: TextPaint(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: _gold,
      ),
    ),
    priority: 12,
  );
  late final TextBoxComponent<TextPaint> dialogue;
  int _textIndex = 0;
  bool _ready = false;
  bool _finished = false;

  int get textIndex => _textIndex;
  bool get isTyping => _ready && isNarrationVisible && !dialogue.finished;
  bool get isFinished => _finished;

  @override
  Future<void> onLoad() async {
    dialogue = TextBoxComponent<TextPaint>(
      text: script.first,
      size: Vector2(280, 100),
      textRenderer: _textPaint(17),
      boxConfig: const TextBoxConfig(
        maxWidth: 280,
        margins: EdgeInsets.zero,
        timePerChar: secondsPerCharacter,
      ),
      onComplete: refreshHint,
      priority: 12,
    );
    await addAll([backdrop, dialoguePanel, _border, _label, dialogue, _hint]);
    _ready = true;
    _layout();
    onTextChanged();
  }

  TextPaint _textPaint(double fontSize) => TextPaint(
    style: TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.35,
      color: const Color(0xFFFFF1D2),
    ),
  );

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
    _layout();
  }

  void refreshSceneLayout() => _layout();

  @override
  void updateTree(double dt) {
    final showNarration = isNarrationVisible;
    update(dt);
    // Keep the line at its first character until the cinematic has finished.
    for (final child in children) {
      if (!showNarration && identical(child, dialogue)) continue;
      child.updateTree(dt);
    }
  }

  @override
  void renderTree(Canvas canvas) {
    if (isNarrationVisible) {
      super.renderTree(canvas);
    } else {
      backdrop.renderTree(canvas);
    }
  }

  void _layout() {
    if (!_ready || size.x <= 0 || size.y <= 0) return;
    final panelWidth = math.min(size.x - 24, 960.0);
    final textWidth = math.max(1.0, panelWidth - 32);
    // Measure the whole line, so typing never moves or expands the panel.
    // Reduce the font only when a short landscape window requires it.
    var fontSize = size.x < 500 ? 15.0 : 18.0;
    double measureLine(String line) {
      final painter = _textPaint(fontSize).toTextPainter(line);
      painter.layout(maxWidth: textWidth);
      final metrics = painter.computeLineMetrics();
      final height = metrics.isEmpty
          ? 0.0
          : metrics.first.height * metrics.length;
      painter.dispose();
      return height.ceilToDouble();
    }

    double measureHeight() => fixedPanelHeight
        ? script.map(measureLine).reduce(math.max)
        : measureLine(script[_textIndex]);
    var textHeight = measureHeight();
    while (textHeight + 72 > size.y - 32 && fontSize > 10) {
      fontSize -= 1;
      textHeight = measureHeight();
    }
    // Fixed bounds avoid async TextBox rasterization restoring an older size.
    dialogue.size.setValues(textWidth, textHeight);
    dialogue.textRenderer = _textPaint(fontSize);
    dialogue.boxConfig = dialogue.boxConfig.copyWith(maxWidth: textWidth);
    final panelHeight = math.max(128.0, textHeight + 72);
    final left = (size.x - panelWidth) / 2;
    final top = size.y - panelHeight - 12;
    dialoguePanel
      ..position.setValues(left, top)
      ..size.setValues(panelWidth, panelHeight);
    _border
      ..position.setValues(left + 4, top + 4)
      ..size.setValues(panelWidth - 8, panelHeight - 8);
    _label.position.setValues(left + 16, top + 13);
    dialogue.position.setValues(left + 16, top + 34);
    _hint.position.setValues(left + 16, size.y - 38);
    backdrop.size.setValues(
      size.x,
      isNarrationVisible ? math.max(1.0, top + 16) : size.y,
    );
  }

  @override
  void onTapUp(TapUpEvent event) => advance();

  /// First tap reveals the line; a separate tap advances, including the last.
  void advance() {
    if (!_ready || _finished || !isNarrationVisible) return;
    if (isTyping) {
      dialogue.skip();
      refreshHint();
      return;
    }
    if (!canAdvance) return;
    if (_textIndex == script.length - 1) {
      finishCutscene();
      return;
    }
    _textIndex++;
    dialogue.resetAnimation();
    // skip() sets timePerChar to zero: restore it for every new line.
    dialogue.text = script[_textIndex];
    dialogue.boxConfig = dialogue.boxConfig.copyWith(
      timePerChar: secondsPerCharacter,
    );
    _layout();
    onTextChanged();
    refreshHint();
  }

  void refreshHint() {
    _hint.text = isTyping
        ? 'TAP TO REVEAL'
        : !canAdvance
        ? waitingHint
        : _textIndex == script.length - 1
        ? (canFinish ? endHint : waitingHint)
        : 'TAP TO CONTINUE >';
  }

  void onTextChanged() => onTextIndexChanged?.call(_textIndex);

  /// Idempotent: rapid taps cannot open multiple story routes.
  void finishCutscene() {
    if (!_ready ||
        _finished ||
        !canAdvance ||
        !canFinish ||
        isTyping ||
        _textIndex != script.length - 1) {
      return;
    }
    _finished = true;
    onFinished();
  }
}
