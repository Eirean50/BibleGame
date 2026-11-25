import 'package:flutter_test/flutter_test.dart';
import 'package:itlective/keyed_art.dart';
import 'package:itlective/level1.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Every player state uses the supplied Michael fight artwork', () async {
    // Deliberately name the required asset: changing the player to an old sheet
    // must fail this regression check, even if its poses still animate.
    final expected = await loadKeyedArt('michaelfight.png');
    final player = AngelPlayer(await loadKeyedArt(AngelPlayer.artAsset));
    addTearDown(() {
      player.onRemove();
      expected.image.dispose();
    });
    void expectMichael() {
      final sprite = player.currentSprite;
      expect(sprite.image.isCloneOf(expected.image), isTrue);
      expect(sprite.srcPosition.x, greaterThanOrEqualTo(0));
      expect(sprite.srcPosition.y, greaterThanOrEqualTo(0));
      expect(
        sprite.srcPosition.x + sprite.srcSize.x,
        lessThanOrEqualTo(sprite.image.width),
      );
      expect(
        sprite.srcPosition.y + sprite.srcSize.y,
        lessThanOrEqualTo(sprite.image.height),
      );
    }

    expectMichael();
    player.isMoving = true;
    expectMichael();
    player.isMoving = false;
    final attackFrames = <Object>{};
    for (final facing in [1.0, -1.0]) {
      player.scale.x = facing;
      expect(player.startAttack(), isTrue);
      for (var frame = 0; frame < 42; frame++) {
        expectMichael();
        attackFrames.add(player.currentSprite);
        player.update(0.01);
      }
      player.cancelAttack();
    }
    expect(attackFrames, hasLength(3));
    player.takeDamage(10);
    expect(player.currentSprite, same(player.damageSprite));
    expectMichael();
    player.restoreHealth();
    player.startUltimate();
    for (var frame = 0; frame < 140; frame++) {
      expectMichael();
      player.update(0.01);
    }
    player.takeDamage(1000);
    expectMichael();
    player.update(1);
    expectMichael();
    player.restoreHealth();
    expectMichael();
  });
}
