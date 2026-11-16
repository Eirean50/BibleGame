import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:itlective/war_video_overlay.dart';
import 'package:video_player/video_player.dart';

import 'fake_video_platform.dart';

void main() {
  late FakeVideoPlatform platform;
  setUp(() {
    final previous = VideoPlayerPlatform.instance;
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
  });

  testWidgets(
    'Movie starts with sound, plays warnew.mp4 immediately after war1stscene.mp4, and finishes once at actual end',
    (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WarVideoOverlay(
            onFinished: () => finished++,
            onError: () => fail('Unexpected video error'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.sources.map((source) => source.asset), [
        'assets/images/war1stscene.mp4',
        'assets/images/warnew.mp4',
      ]);
      expect(platform.playing, isNot(contains(1)));
      expect(platform.volumes[1], 0);
      expect(platform.looping[0], isFalse);
      expect(platform.playing, contains(0));
      expect(platform.volumes[0], 1);
      expect(find.text('Play with sound'), findsNothing);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The video covers the viewport without stretching or revealing a
      // separate kingdom background, including after resizing.
      for (final size in [const Size(1920, 945), const Size(320, 568)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final videoRect = tester.getRect(find.byType(VideoPlayer));
        expect(videoRect.width / videoRect.height, closeTo(16 / 9, 0.001));
        expect(videoRect.top, lessThanOrEqualTo(0.001));
        expect(videoRect.left, lessThanOrEqualTo(0.001));
        expect(videoRect.right, greaterThanOrEqualTo(size.width - 0.001));
        expect(videoRect.bottom, greaterThanOrEqualTo(size.height - 0.001));
        expect(find.byType(Image), findsNothing);
        expect(find.byKey(const ValueKey('war-video-panel')), findsNothing);
        expect(platform.sources, hasLength(2));
      }
      await tester.tap(find.byTooltip('Mute sound'));
      await tester.pump();
      expect(platform.volumes[0], 0);
      await tester.tap(find.byTooltip('Enable sound'));
      await tester.pump();
      expect(platform.volumes[0], 1);

      // Complete war1stscene.mp4: warnew.mp4 plays immediately.
      platform.streams[0]!.add(VideoEvent(eventType: VideoEventType.completed));
      await tester.pump();
      await tester.pump();
      expect(finished, 0);
      expect(platform.playing, isNot(contains(0)));
      expect(platform.playing, contains(1));
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.volumes[1], 1);

      // Only the second clip's completion enters Genesis.
      platform.streams[1]!.add(VideoEvent(eventType: VideoEventType.completed));
      await tester.pump();
      expect(finished, 1);
      await tester.tap(find.text('SKIP TO GENESIS >'));
      expect(finished, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      expect(platform.disposed, unorderedEquals([0, 1]));
    },
  );

  testWidgets('Skip while loading disposes video and cancels late navigation', (
    tester,
  ) async {
    platform.initializeImmediately = false;
    var finished = 0;
    var failed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WarVideoOverlay(
          onFinished: () => finished++,
          onError: () => failed++,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('SKIP TO GENESIS >'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 25));
    expect(finished, 1);
    expect(failed, 0);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    expect(platform.disposed, [0]);
  });

  testWidgets(
    'Blocked audio retries muted automatically; decode errors finish once',
    (tester) async {
      platform.rejectAutoplay = true;
      var failed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WarVideoOverlay(
            onFinished: () => fail('Unexpected finish'),
            onError: () => failed++,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Play with sound'), findsNothing);
      expect(platform.playing, contains(2));
      expect(platform.volumes[2], 0);
      expect(find.byTooltip('Enable sound'), findsOneWidget);
      platform.streams[2]!.addError(
        PlatformException(code: 'decode_error', message: 'Invalid video'),
      );
      await tester.pump();
      expect(failed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      expect(platform.disposed, unorderedEquals([0, 1, 2]));
    },
  );

  testWidgets(
    'Web-style autoplay error events also retry without skipping the movie',
    (tester) async {
      platform.rejectAutoplay = true;
      platform.autoplayErrorViaStream = true;
      await tester.pumpWidget(
        MaterialApp(
          home: WarVideoOverlay(
            onFinished: () => fail('Must not skip movie'),
            onError: () => fail('Autoplay denial is recoverable'),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      expect(platform.sources, hasLength(3));
      expect(platform.playing, contains(2));
      expect(platform.volumes[2], 0);
      expect(find.text('Play with sound'), findsNothing);
      await tester.tap(find.byTooltip('Enable sound'));
      await tester.pump();
      expect(platform.volumes[2], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      expect(platform.disposed, unorderedEquals([0, 1, 2]));
    },
  );
}
