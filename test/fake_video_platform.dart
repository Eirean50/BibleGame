import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final streams = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final playing = <int>{};
  final looping = <int, bool>{};
  final volumes = <int, double>{};
  bool initializeImmediately = true;
  bool rejectAutoplay = false;
  bool autoplayErrorViaStream = false;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length;
    sources.add(options.dataSource);
    streams[id] = StreamController<VideoEvent>(
      onListen: () {
        if (initializeImmediately) {
          streams[id]!.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: const Duration(seconds: 10),
              size: const Size(1280, 720),
            ),
          );
        }
      },
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing.remove(playerId);
    await streams[playerId]!.close();
  }

  @override
  Future<void> setLooping(int playerId, bool value) async =>
      looping[playerId] = value;
  @override
  Future<void> setVolume(int playerId, double value) async =>
      volumes[playerId] = value;
  @override
  Future<void> play(int playerId) async {
    if (rejectAutoplay && volumes[playerId] != 0) {
      final error = PlatformException(
        code: 'NotAllowedError',
        message: "play() failed because the user didn't interact with the document first.",
      );
      if (autoplayErrorViaStream) {
        streams[playerId]!.addError(error);
        return;
      }
      throw error;
    }
    playing.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}
