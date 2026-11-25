import 'dart:async';

import 'package:flame/components.dart';

import 'sword_sound.dart';

enum GenesisAmbience { waters, wind, nature }

/// Scene-owned ambience and reveal cues; no audio survives leaving the scene.
class GenesisAudio extends Component {
  GenesisAudio({
    GenesisAmbience initialAmbience = GenesisAmbience.waters,
    SwordSound? waters,
    SwordSound? wind,
    SwordSound? nature,
    SwordSound? reveal,
  }) : _ambience = initialAmbience,
       _loops = {
         GenesisAmbience.waters:
             waters ?? SwordSound(asset: watersAsset, volume: 0.45, loop: true),
         GenesisAmbience.wind:
             wind ?? SwordSound(asset: windAsset, volume: 0.40, loop: true),
         GenesisAmbience.nature:
             nature ?? SwordSound(asset: natureAsset, volume: 0.40, loop: true),
       },
       _reveal = reveal ?? SwordSound(asset: revealAsset, volume: 0.55);

  static const watersAsset = 'audio/genesis_waters.wav';
  static const windAsset = 'audio/genesis_wind.wav';
  static const natureAsset = 'audio/genesis_nature.wav';
  static const revealAsset = 'audio/genesis_reveal.wav';
  static const assets = [watersAsset, windAsset, natureAsset, revealAsset];

  final Map<GenesisAmbience, SwordSound> _loops;
  final SwordSound _reveal;
  GenesisAmbience _ambience;
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
    final next = index >= 11
        ? GenesisAmbience.nature
        : index >= 4
        ? GenesisAmbience.wind
        : GenesisAmbience.waters;
    if (next != _ambience) {
      if (!_suspended) unawaited(_loops[_ambience]!.stop());
      _ambience = next;
      if (!_suspended) unawaited(_loops[_ambience]!.play());
    }
    // Light, land, heavenly lights, and the formation of mankind.
    if (!_suspended && const [2, 6, 9, 13].contains(index)) {
      unawaited(_reveal.play());
    }
  }

  void pauseAudio() {
    if (_disposed) return;
    _suspended = true;
    for (final sound in [..._loops.values, _reveal]) {
      unawaited(sound.stop());
    }
  }

  void resumeAudio() {
    if (!_active || _disposed || !_suspended) return;
    _suspended = false;
    unawaited(_loops[_ambience]!.play());
  }

  void disposeAudio() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    for (final sound in [..._loops.values, _reveal]) {
      unawaited(sound.dispose());
    }
  }

  @override
  void onRemove() {
    disposeAudio();
    super.onRemove();
  }
}
