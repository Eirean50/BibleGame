import 'dart:async';

import 'package:flame/components.dart';

import 'sword_sound.dart';

/// Scene-owned reveal cues. Continuous water/wind/nature loops are disabled;
/// the game-owned musical score supplies the background audio.
class GenesisAudio extends Component {
  GenesisAudio({SwordSound? reveal, SwordSound? footsteps})
    : _reveal = reveal ?? SwordSound(asset: revealAsset, volume: 0.55),
      _footsteps = footsteps ?? SwordSound(asset: footstepsAsset, volume: 0.32);

  static const revealAsset = 'audio/genesis_reveal.wav';
  static const footstepsAsset = 'audio/genesis_footsteps.wav';
  static const assets = [revealAsset, footstepsAsset];

  final SwordSound _reveal;
  final SwordSound _footsteps;
  int _lastStep = -1;
  bool _suspended = true;
  bool _active = false;
  bool _disposed = false;

  @override
  void onMount() {
    super.onMount();
    _active = true;
    resumeAudio();
  }

  void creationStep(int index) {
    if (_disposed || index == _lastStep) return;
    _lastStep = index;
    // Light, land, heavenly lights, and the formation of mankind.
    if (!_suspended && const [2, 6, 9, 13].contains(index)) {
      unawaited(_reveal.play());
    }
  }

  void pauseAudio() {
    if (_disposed) return;
    _suspended = true;
    unawaited(_reveal.stop());
    unawaited(_footsteps.stop());
  }

  /// A single creation chime for a visual miracle in the active scene.
  void revealMoment() {
    if (_active && !_disposed && !_suspended) unawaited(_reveal.play());
  }

  void walkingMoment() {
    if (_active && !_disposed && !_suspended) unawaited(_footsteps.play());
  }

  void resumeAudio() {
    if (!_active || _disposed || !_suspended) return;
    _suspended = false;
  }

  void disposeAudio() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    unawaited(_reveal.dispose());
    unawaited(_footsteps.dispose());
  }

  @override
  void onRemove() {
    disposeAudio();
    super.onRemove();
  }
}
