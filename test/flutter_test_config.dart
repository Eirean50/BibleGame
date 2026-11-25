import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Story/gameplay now starts ambient audio on entry. Widget tests have no native
// audio host, so emulate preparation and seeking while using the real assets.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channels = <MethodChannel>[];
    void mock(String name, Future<Object?> Function(MethodCall) handler) {
      final channel = MethodChannel(name);
      channels.add(channel);
      messenger.setMockMethodCallHandler(channel, handler);
    }

    void event(String id, String name) {
      messenger.handlePlatformMessage(
        'xyz.luan/audioplayers/events/$id',
        const StandardMethodCodec().encodeSuccessEnvelope({
          'event': name,
          'value': true,
        }),
        (_) {},
      );
    }

    mock('xyz.luan/audioplayers.global', (_) async => null);
    mock('xyz.luan/audioplayers.global/events', (_) async => null);
    mock('xyz.luan/audioplayers', (call) async {
      final id = (call.arguments as Map)['playerId'] as String;
      switch (call.method) {
        case 'create':
          mock('xyz.luan/audioplayers/events/$id', (_) async => null);
        case 'setSourceUrl':
          event(id, 'audio.onPrepared');
        case 'seek':
          event(id, 'audio.onSeekComplete');
        case 'getDuration':
          return 24000;
        case 'getCurrentPosition':
          return 0;
      }
      return null;
    });
    final previous = AudioCache.instance;
    AudioCache.instance = AudioCache();
    for (final name in [
      'sword_attack.wav',
      'sword_slash.wav',
      'warnew_battle.m4a',
      "Tim Curry's devil laugh (legend).mp3",
      'genesis_waters.wav',
      'genesis_wind.wav',
      'genesis_nature.wav',
      'genesis_reveal.wav',
    ]) {
      AudioCache.instance.loadedFiles['audio/$name'] = File(
        'assets/audio/$name',
      ).absolute.uri;
    }
    addTearDown(() {
      AudioCache.instance = previous;
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  });
  await testMain();
}
