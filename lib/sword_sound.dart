import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// One reusable sound player per kingdom visit, created on the first gesture.
class SwordSound {
  AudioPlayer? _player;
  Future<void>? _preparation;
  bool _disposed = false;
  int _request = 0;

  Future<void> _prepare(AudioPlayer player) async {
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(0.75);
    await player.setSource(AssetSource('audio/sword_slash.wav'));
  }

  Future<void> play() async {
    if (_disposed) return;
    final request = ++_request;
    try {
      final player = _player ??= AudioPlayer();
      await (_preparation ??= _prepare(player));
      if (_disposed || request != _request) return;
      await player.seek(Duration.zero);
      if (_disposed || request != _request) return;
      await player.resume();
    } catch (error) {
      debugPrint('Sword sound unavailable: $error');
    }
  }

  Future<void> stop() async {
    final request = ++_request;
    try {
      await _preparation;
      if (!_disposed && request == _request) await _player?.stop();
    } catch (error) {
      debugPrint('Could not stop sword sound: $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _request++;
    try {
      await _preparation;
    } catch (_) {
      // A failed preparation still owns a native player that needs disposal.
    }
    try {
      await _player?.dispose();
    } catch (error) {
      debugPrint('Could not dispose sword sound: $error');
    }
  }
}
