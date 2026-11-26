import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/sword_sound.dart';
import 'package:itlective/level1.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('Sword audio loads a real WAV, reuses playback and disposes on exit', () async {
    final asset = await rootBundle.load('assets/audio/sword_slash.wav');
    final bytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(asset.getUint32(24, Endian.little), 44100);
    expect(asset.getUint32(40, Endian.little), bytes.length - 44);
    var peak = 0;
    for (var i = 44; i < bytes.length; i += 2) {
      final sample = asset.getInt16(i, Endian.little).abs();
      if (sample > peak) peak = sample;
    }
    expect(peak, inExclusiveRange(1000, 32767));

    final messenger = binding.defaultBinaryMessenger;
    final channels = <MethodChannel>[];
    void mock(String name, Future<Object?> Function(MethodCall) handler) {
      final channel = MethodChannel(name);
      channels.add(channel);
      messenger.setMockMethodCallHandler(channel, handler);
    }

    void event(String playerId, String name, [Object? value]) {
      messenger.handlePlatformMessage(
        'xyz.luan/audioplayers/events/$playerId',
        const StandardMethodCodec().encodeSuccessEnvelope({
          'event': name,
          'value': value,
        }),
        (_) {},
      );
    }

    final calls = <MethodCall>[];
    mock('xyz.luan/audioplayers.global', (_) async => null);
    mock('xyz.luan/audioplayers.global/events', (_) async => null);
    mock('xyz.luan/audioplayers', (call) async {
      calls.add(call);
      final id = (call.arguments as Map)['playerId'] as String;
      switch (call.method) {
        case 'create':
          mock('xyz.luan/audioplayers/events/$id', (_) async => null);
        case 'setSourceUrl':
          event(id, 'audio.onPrepared', true);
        case 'seek':
          event(id, 'audio.onSeekComplete');
        case 'getDuration':
          return 360;
        case 'getCurrentPosition':
          return 0;
      }
      return null;
    });
    // Point the cache at the real bundled sound without a native temp-directory
    // plugin; all playback still goes through AudioPlayer's platform messages.
    final previousCache = AudioCache.instance;
    AudioCache.instance = AudioCache()
      ..loadedFiles['audio/sword_slash.wav'] = File(
        'assets/audio/sword_slash.wav',
      ).absolute.uri
      ..loadedFiles[Level1.battleAudioAsset] = File(
        'assets/${Level1.battleAudioAsset}',
      ).absolute.uri
      ..loadedFiles[Level1.defeatAudioAsset] = File(
        'assets/${Level1.defeatAudioAsset}',
      ).absolute.uri;
    addTearDown(() {
      AudioCache.instance = previousCache;
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
    final sound = SwordSound();
    await sound.setGain(0);
    await sound.play();
    final muted = calls.singleWhere((call) => call.method == 'setVolume');
    expect((muted.arguments as Map)['volume'], 0);
    await sound.setGain(0.5);
    final faded = calls.lastWhere((call) => call.method == 'setVolume');
    expect((faded.arguments as Map)['volume'], 0.375);
    await sound.setGain(1);
    await sound.play();
    expect(calls.where((call) => call.method == 'create'), hasLength(1));
    expect(calls.where((call) => call.method == 'setSourceUrl'), hasLength(1));
    expect(calls.where((call) => call.method == 'resume'), hasLength(2));
    final source = calls.singleWhere((call) => call.method == 'setSourceUrl');
    expect((source.arguments as Map)['url'], endsWith('sword_slash.wav'));
    for (final seek in calls.where((call) => call.method == 'seek')) {
      expect((seek.arguments as Map)['position'], 0);
    }
    await sound.stop();
    expect(calls.where((call) => call.method == 'stop'), isNotEmpty);
    await sound.dispose();
    await sound.dispose();
    await sound.play();
    expect(calls.where((call) => call.method == 'dispose'), hasLength(1));
    expect(calls.where((call) => call.method == 'resume'), hasLength(2));
    calls.clear();
    final ambience = SwordSound(
      asset: Level1.battleAudioAsset,
      volume: 0.65,
      loop: true,
    );
    await ambience.play();
    final mode = calls.singleWhere((call) => call.method == 'setReleaseMode');
    expect((mode.arguments as Map)['releaseMode'], ReleaseMode.loop.toString());
    final volume = calls.singleWhere((call) => call.method == 'setVolume');
    expect((volume.arguments as Map)['volume'], 0.65);
    final ambientSource = calls.singleWhere(
      (call) => call.method == 'setSourceUrl',
    );
    expect(
      (ambientSource.arguments as Map)['url'],
      endsWith('warnew_battle.m4a'),
    );
    await ambience.stop();
    await ambience.play();
    expect(calls.where((call) => call.method == 'create'), hasLength(1));
    await ambience.dispose();
    await ambience.play();
    expect(calls.where((call) => call.method == 'resume'), hasLength(2));
    calls.clear();
    final laugh = SwordSound(asset: Level1.defeatAudioAsset, volume: 0.85);
    await laugh.play();
    final laughSource = calls.singleWhere(
      (call) => call.method == 'setSourceUrl',
    );
    expect(
      Uri.decodeFull((laughSource.arguments as Map)['url'] as String),
      endsWith("Tim Curry's devil laugh (legend).mp3"),
    );
    final laughMode = calls.singleWhere(
      (call) => call.method == 'setReleaseMode',
    );
    expect(
      (laughMode.arguments as Map)['releaseMode'],
      ReleaseMode.stop.toString(),
    );
    await laugh.stop();
    await laugh.dispose();
  });

  test(
    'The supplied Tim Curry MP3 is bundled intact for defeat playback',
    () async {
      final asset = await rootBundle.load('assets/${Level1.defeatAudioAsset}');
      final bytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      final supplied = await File(
        "assets/audio/Tim Curry's devil laugh (legend).mp3",
      ).readAsBytes();
      expect(bytes, orderedEquals(supplied));
      expect(bytes.length, greaterThan(10000));
      final hasId3 = String.fromCharCodes(bytes.take(3)) == 'ID3';
      final hasMpegSync = bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0;
      expect(hasId3 || hasMpegSync, isTrue);
    },
  );
}
