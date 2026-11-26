import 'dart:async';

import 'sword_sound.dart';

/// Owned by the game so the soundtrack continues between Genesis scenes.
class GenesisMusic {
  GenesisMusic({SwordSound? sound, SwordSound? serpentSound})
    : _sound = sound ?? SwordSound(asset: asset, volume: 0.40, loop: true),
      _serpent =
          serpentSound ??
          SwordSound(asset: serpentAsset, volume: 0.40, loop: true);

  static const asset = 'audio/genesis_music.wav';
  static const serpentAsset = 'audio/genesis_serpent_music.wav';
  static const fadeDuration = 2.5;
  final SwordSound _sound;
  final SwordSound _serpent;
  bool _active = false;
  bool _playing = false;
  bool _serpentPlaying = false;
  bool _serpentTheme = false;
  double _blend = 0;
  bool _suspended = false;
  bool _disposed = false;

  void start() {
    if (_disposed) return;
    _active = true;
    _playIfNeeded();
  }

  void _playIfNeeded() {
    if (!_active || _suspended || _disposed) return;
    if (!_playing && _blend < 1) {
      _playing = true;
      unawaited(_sound.setGain(1 - _blend));
      unawaited(_sound.play());
    }
    if (!_serpentPlaying && _serpentTheme) {
      _serpentPlaying = true;
      unawaited(_serpent.setGain(_blend));
      unawaited(_serpent.play());
    }
  }

  void useSerpentTheme() {
    if (_disposed || _serpentTheme) return;
    _serpentTheme = true;
    start();
  }

  void update(double dt) {
    if (!_active || _suspended || _disposed || !_serpentTheme || _blend >= 1) {
      return;
    }
    _blend = (_blend + dt.clamp(0.0, fadeDuration) / fadeDuration).clamp(
      0.0,
      1.0,
    );
    unawaited(_sound.setGain(1 - _blend));
    unawaited(_serpent.setGain(_blend));
    if (_blend == 1 && _playing) {
      _playing = false;
      unawaited(_sound.stop());
    }
  }

  void pause() {
    if (_disposed) return;
    _suspended = true;
    _playing = false;
    _serpentPlaying = false;
    unawaited(_sound.stop());
    unawaited(_serpent.stop());
  }

  void resume() {
    if (_disposed) return;
    _suspended = false;
    _playIfNeeded();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _playing = false;
    unawaited(_sound.dispose());
    unawaited(_serpent.dispose());
  }
}
