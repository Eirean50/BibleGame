import 'dart:async';

import 'package:flame/components.dart';

import 'sword_sound.dart';

/// Scene-owned reveal cues. Continuous water/wind/nature loops are disabled;
/// the game-owned musical score supplies the background audio.
class GenesisAudio extends Component {
  GenesisAudio({SwordSound? reveal})
    : _reveal = reveal ?? SwordSound(asset: revealAsset, volume: 0.55);

  static const revealAsset = 'audio/genesis_reveal.wav';
  static const assets = [revealAsset];

  final SwordSound _reveal;
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
  }

  /// A single creation chime for a visual miracle in the active scene.
  void revealMoment() {
    if (_active && !_disposed && !_suspended) unawaited(_reveal.play());
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
  }

  @override
  void onRemove() {
    disposeAudio();
    super.onRemove();
  }
}
