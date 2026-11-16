import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Fullscreen movie playback without a separate scene background or frame.
class WarVideoOverlay extends StatefulWidget {
  const WarVideoOverlay({
    super.key,
    required this.onFinished,
    required this.onError,
  });
  final VoidCallback onFinished;
  final VoidCallback onError;

  @override
  State<WarVideoOverlay> createState() => _WarVideoOverlayState();
}

class _WarVideoOverlayState extends State<WarVideoOverlay> {
  static const _clips = [
    'assets/images/war1stscene.mp4',
    'assets/images/warnew.mp4',
  ];
  late VideoPlayerController _controller;
  VideoPlayerController? _preloaded;
  Future<bool>? _nextReady;
  bool _advancing = false;
  int _clipIndex = 0;
  bool _ready = false;
  bool _ended = false;
  bool _muted = false;
  bool _retriedMuted = false;
  Timer? _loadingTimer;
  Timer? _preloadTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(_clips.first);
    _controller.addListener(_onVideoChanged);
    _loadingTimer = Timer(
      const Duration(seconds: 20),
      () => _fallback('Loading timed out'),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final controller = _controller;
    try {
      await controller.initialize();
      if (!mounted || _ended || controller != _controller) return;
      _loadingTimer?.cancel();
      await controller.setLooping(false);
      if (_clipIndex == 0 && _nextReady == null) {
        final next = VideoPlayerController.asset(_clips[1]);
        _preloaded = next;
        _nextReady = _prepareNext(next);
      }
      await _playActive(controller);
    } catch (error) {
      _handlePlaybackError(controller, error);
    }
  }

  Future<bool> _prepareNext(VideoPlayerController controller) async {
    final timeout = Completer<void>();
    _preloadTimer = Timer(
      const Duration(seconds: 20),
      () => timeout.completeError(StateError('Second clip loading timed out')),
    );
    try {
      await Future.any([controller.initialize(), timeout.future]);
      if (!mounted || _ended) return false;
      await controller.setLooping(false);
      await controller.setVolume(0);
      return true;
    } catch (error) {
      debugPrint('Could not prepare the second battle clip: $error');
      return false;
    } finally {
      _preloadTimer?.cancel();
    }
  }

  Future<void> _playActive(VideoPlayerController controller) async {
    try {
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || _ended || controller != _controller) return;
      setState(() => _ready = true);
      await controller.play();
    } catch (error) {
      _handlePlaybackError(controller, error);
    }
  }

  void _handlePlaybackError(VideoPlayerController controller, Object? error) {
    if (!mounted || _ended || controller != _controller) return;
    if (!_retriedMuted && _isAutoplayDenied(error)) {
      unawaited(_retryMuted());
    } else {
      _fallback(error);
    }
  }

  Future<void> _advanceToBattle() async {
    if (_advancing || _ended || _clipIndex != 0) return;
    _advancing = true;
    final previous = _controller;
    previous.removeListener(_onVideoChanged);
    unawaited(previous.pause());
    final ready = await (_nextReady ?? Future.value(false));
    if (!mounted || _ended) return;
    if (ready && _preloaded != null) {
      setState(() {
        _controller = _preloaded!;
        _preloaded = null;
        _clipIndex = 1;
        _retriedMuted = false;
        _controller.addListener(_onVideoChanged);
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(previous.dispose()),
      );
      await _playActive(_controller);
      return;
    }

    // Fallback: dispose the first controller to free the hardware decoder,
    // then initialize and play warnew.mp4 directly.
    final failedPreload = _preloaded;
    _preloaded = null;
    if (failedPreload != null) {
      unawaited(failedPreload.dispose());
    }
    await previous.dispose();
    if (!mounted || _ended) return;
    setState(() {
      _ready = false;
      _clipIndex = 1;
      _retriedMuted = false;
      _controller = VideoPlayerController.asset(_clips[1]);
      _controller.addListener(_onVideoChanged);
    });
    _loadingTimer?.cancel();
    _loadingTimer = Timer(
      const Duration(seconds: 20),
      () => _fallback('Second battle clip loading timed out'),
    );
    await _initialize();
  }

  bool _isAutoplayDenied(Object? error) {
    if (error is PlatformException && error.code == 'NotAllowedError') {
      return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('notallowederror') ||
        message.contains('not allowed by the user agent') ||
        message.contains("user didn't interact") ||
        message.contains('user gesture') ||
        message.contains('user denied permission');
  }

  Future<void> _retryMuted() async {
    if (!mounted || _ended || _retriedMuted) return;
    _retriedMuted = true;
    final previous = _controller;
    previous.removeListener(_onVideoChanged);
    // The web plugin marks the controller erroneous on autoplay rejection.
    // Recreate it once to clear that error, then autoplay without audio.
    setState(() {
      _ready = false;
      _muted = true;
      _controller = VideoPlayerController.asset(_clips[_clipIndex]);
      _controller.addListener(_onVideoChanged);
    });
    _loadingTimer?.cancel();
    _loadingTimer = Timer(
      const Duration(seconds: 20),
      () => _fallback('Loading timed out'),
    );
    await previous.dispose();
    if (!mounted || _ended) return;
    await _initialize();
  }

  void _onVideoChanged() {
    if (!mounted || _ended) return;
    final value = _controller.value;
    if (value.hasError) {
      if (!_retriedMuted && _isAutoplayDenied(value.errorDescription)) {
        unawaited(_retryMuted());
      } else {
        _fallback(value.errorDescription);
      }
    } else if (value.isCompleted ||
        (value.isInitialized &&
            value.duration > Duration.zero &&
            value.position >= value.duration)) {
      if (_clipIndex == 0) {
        unawaited(_advanceToBattle());
      } else {
        _finish();
      }
    }
  }

  void _finish() {
    if (_ended) return;
    _ended = true;
    unawaited(_controller.pause());
    widget.onFinished();
  }

  void _fallback(Object? error) {
    if (!mounted || _ended) return;
    debugPrint('Battle video unavailable; continuing to gameplay: $error');
    _ended = true;
    _loadingTimer?.cancel();
    widget.onError();
  }

  Future<void> _toggleSound() async {
    final muted = !_muted;
    try {
      await _controller.setVolume(muted ? 0 : 1);
      if (mounted && !_ended) setState(() => _muted = muted);
    } catch (_) {
      // Preserve the current audio indicator if the platform rejects a change.
    }
  }

  @override
  void dispose() {
    _ended = true;
    _loadingTimer?.cancel();
    _preloadTimer?.cancel();
    _controller.removeListener(_onVideoChanged);
    unawaited(_controller.dispose());
    if (_preloaded != null) unawaited(_preloaded!.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (_ready) _video(_controller),
        if (!_ready)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFF4CB80)),
          ),
        if (_ready)
          Positioned(
            left: 12,
            bottom: 12,
            child: IconButton.filled(
              tooltip: _muted ? 'Enable sound' : 'Mute sound',
              onPressed: _toggleSound,
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 12,
          width: 196,
          height: 46,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xDD101426),
              foregroundColor: const Color(0xFFFFE5A1),
              side: const BorderSide(color: Color(0xFFE8C681)),
              shape: const RoundedRectangleBorder(),
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            onPressed: _finish,
            child: const Text('SKIP TO GAMEPLAY >'),
          ),
        ),
      ],
    );
  }

  Widget _video(VideoPlayerController controller) => ClipRect(
    key: ObjectKey(controller),
    child: SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    ),
  );
}
