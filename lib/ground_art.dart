import 'package:flame/components.dart';

import 'keyed_art.dart';

/// Loads the foreground; the caller owns the returned image.
Future<Sprite> loadGroundArt() => loadKeyedArt('Ground.png');
