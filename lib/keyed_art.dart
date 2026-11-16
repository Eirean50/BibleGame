import 'package:flame/components.dart';
import 'package:flame/flame.dart';

const preparedArtNames = [
  'Ground.png',
  'Bird.png',
  'Deer.png',
  'lion.png',
  'human.png',
];

/// Load artwork keyed offline by tool/prepare_art_test.dart.
/// The shared cache survives Replay and Back; each scene owns only a clone.
/// Disposing a scene's clone never invalidates the cached image or another scene.
Future<Sprite> loadKeyedArt(String assetName) async {
  final image = await Flame.images.load('prepared/$assetName');
  return Sprite(image.clone());
}
