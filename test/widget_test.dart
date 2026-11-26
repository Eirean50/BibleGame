import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/main.dart';
import 'package:itlective/main_menu_screen.dart';
import 'package:itlective/creation_backdrop.dart';
import 'package:itlective/old_testament_game.dart';
import 'package:itlective/story_screen.dart';

import 'story_test_helpers.dart';
import 'fake_video_platform.dart';

import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  setUp(() {
    final previousVideoPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = previousVideoPlatform);
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
  });
  testWidgets('Story restarts after back and supports replay from Eden', (
    WidgetTester tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final fullscreenCalls = <bool>[];
    const display = MethodChannel('daloy/display');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(display, (
      call,
    ) async {
      fullscreenCalls.add(call.arguments as bool);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        display,
        null,
      ),
    );
    await tester.pumpWidget(const OldTestamentApp());
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final game = tester
        .state<GameWidgetState<OldTestamentGame>>(
          find.byType(GameWidget<OldTestamentGame>),
        )
        .currentGame;
    await enterGenesis(tester, game);
    await tester.pump();
    // A running game schedules frames continuously; pause before settling.
    game.pauseEngine();
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Bumalik sa menu'), findsOneWidget);
    expect(fullscreenCalls.last, isTrue);
    expect(game.isLoaded, isTrue);
    expect(game.backgroundColor(), const Color(0xFF090E20));
    expect(tester.takeException(), isNull);

    // Advance far enough to run the one-shot human formation before leaving.
    expect(game.cutscene.isMounted, isTrue);
    for (var tap = 0; tap < 30 && game.cutscene.textIndex < 13; tap++) {
      game.cutscene.advance();
    }
    game.update(0);
    game.update(1.3);
    game.update(10);
    expect(
      game
          .cutscene
          .backdrop
          .layers[CreationStage.people]!
          .humanCreation!
          .isFormed,
      isTrue,
    );

    await tester.tap(find.byTooltip('Bumalik sa menu'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryScreen), findsNothing);
    expect(find.text('OLD TESTAMENT'), findsOneWidget);
    expect(fullscreenCalls.last, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final replay = tester
        .state<GameWidgetState<OldTestamentGame>>(
          find.byType(GameWidget<OldTestamentGame>),
        )
        .currentGame;
    await enterGenesis(tester, replay);
    replay.pauseEngine();
    await tester.pumpAndSettle();
    expect(replay, isNot(same(game)));
    expect(replay.cutscene.isMounted, isTrue);
    expect(replay.cutscene.textIndex, 0);
    expect(replay.cutscene.isFinished, isFalse);
    expect(replay.cutscene.backdrop.revealed, isEmpty);
    expect(
      replay
          .cutscene
          .backdrop
          .layers[CreationStage.people]!
          .humanCreation!
          .currentStage,
      0,
    );
    for (var tap = 0; tap < 30 && replay.cutscene.textIndex < 13; tap++) {
      replay.cutscene.advance();
    }
    replay.update(0);
    replay.update(1.3);
    replay.update(2);
    await tester
        .pump(); // Paint all reloaded artwork, including the sky shader.
    final human =
        replay.cutscene.backdrop.layers[CreationStage.people]!.humanCreation!;
    expect(human.currentStage, greaterThan(0));
    expect(human.lightIntensity, greaterThan(0));
    expect(tester.takeException(), isNull);

    for (var tap = 0; tap < 6 && !replay.cutscene.isFinished; tap++) {
      replay.cutscene.advance();
    }
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        replay.update(0);
        await tester.pump();
        if (replay.router.currentRoute.isMounted &&
            replay.router.currentRoute.name == 'eden' &&
            replay.router.currentRoute.children.isNotEmpty) {
          break;
        }
      }
    });
    expect(replay.router.currentRoute.name, 'eden');
    await tester.tap(find.byTooltip('Ulitin ang cutscene'));
    await tester.pump();
    final restarted = tester
        .state<GameWidgetState<OldTestamentGame>>(
          find.byType(GameWidget<OldTestamentGame>),
        )
        .currentGame;
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 500; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (restarted.isLoaded &&
            restarted.router.currentRoute.name == 'intro' &&
            restarted.cutscene.isMounted) {
          break;
        }
      }
    });
    restarted.pauseEngine();
    await tester.pumpAndSettle();
    expect(restarted, isNot(same(replay)));
    expect(restarted.cutscene.isMounted, isTrue);
    expect(restarted.router.currentRoute.name, 'intro');
    expect(
      restarted.overlays.isActive(OldTestamentGame.warVideoOverlay),
      isFalse,
    );
    expect(restarted.cutscene.textIndex, 0);
    expect(restarted.cutscene.backdrop.revealed, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute(); // Android/system back also exits.
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Menu visits play the opening clips; Genesis replay does not replay them.
    expect(
      (VideoPlayerPlatform.instance as FakeVideoPlatform).sources,
      hasLength(4),
    );
  });

  testWidgets('Main menu shows artwork and only the Play action', (
    tester,
  ) async {
    await tester.pumpWidget(const OldTestamentApp());
    expect(find.text('OLD TESTAMENT'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    for (final label in [
      'Pagsusulit at Trivia',
      'Talaan ng Lumang Tipan',
      'Mga Gantimpala',
      'Mga Setting',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(HolySpiritEmblem), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HeavenBackdrop),
        matching: find.byType(HolySpiritEmblem),
      ),
      findsOneWidget,
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(1440, 900),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('Title screen at $size with text scale $textScale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const OldTestamentApp());
        await tester.ensureVisible(find.text('Play'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getBottomRight(find.widgetWithText(FilledButton, 'Play')).dy,
          lessThanOrEqualTo(size.height - 24),
        );
        expect(find.text('Play').hitTestable(), findsOneWidget);
      });
    }
  }
}
