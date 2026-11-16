import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'old_testament_game.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> with WidgetsBindingObserver {
  static const _displayChannel = MethodChannel('daloy/display');
  // Each menu visit and replay owns a fresh game, including all animation clocks.
  OldTestamentGame _game = OldTestamentGame();

  void _replay() {
    setState(() => _game = OldTestamentGame());
  }

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
            child: SafeArea(
              child: GameWidget<OldTestamentGame>(
                // Replace the entire host so the previous game is unmounted.
                key: ObjectKey(_game),
                game: _game,
                loadingBuilder: (context) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF4CB80)),
                ),
                errorBuilder: (context, error) {
                  debugPrint('Story loading failed: $error');
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
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.all(8),
              child: IconButton.filled(
                tooltip: 'Ulitin ang cutscene',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xB3352631),
                  foregroundColor: const Color(0xFFFFEDCF),
                ),
                onPressed: _replay,
                icon: const Icon(Icons.replay),
              ),
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
