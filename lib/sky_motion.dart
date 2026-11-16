import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Local wind motion for the clouds and plume painted into bg_sky.png.
/// A textured mesh moves selected regions without rectangular crop seams or
/// duplicating clouds. The mountains, image edges and horizon stay anchored.
class SkyMotion {
  SkyMotion(ui.Image image) {
    _shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      filterQuality: ui.FilterQuality.none,
    );
    for (var row = 0; row <= _rows; row++) {
      for (var col = 0; col <= _columns; col++) {
        final index = row * (_columns + 1) + col;
        final x = col * 320 / _columns;
        final y = row * 112 / _rows;
        _rest[index * 2] = x;
        _rest[index * 2 + 1] = y;
        _texture[index * 2] = x / 320 * image.width;
        // Only the painted upper half; exclude the checkerboard margin.
        _texture[index * 2 + 1] = y / 112 * (image.height / 2 - 1);

        // Cloud centers/radii measured in the 320x112 sky stage.
        var cloud = 0.0;
        for (final region in _cloudRegions) {
          cloud = math.max(cloud, _influence(x, y, region));
        }
        final edge = math.min(1.0, math.min(x, 320 - x) / 8);
        _cloudWeight[index] = cloud * edge;
        // The plume sways more near its top and stays fixed at the crater.
        _smokeWeight[index] =
            _influence(x, y, const [267, 9, 35, 24]) *
            (1 - y / 32).clamp(0.0, 1.0) *
            (y / 5).clamp(0.0, 1.0);
      }
    }
    var offset = 0;
    for (var row = 0; row < _rows; row++) {
      for (var col = 0; col < _columns; col++) {
        final top = row * (_columns + 1) + col;
        final bottom = top + _columns + 1;
        for (final vertex in [
          top,
          bottom,
          top + 1,
          top + 1,
          bottom,
          bottom + 1,
        ]) {
          _indices[offset++] = vertex;
        }
      }
    }
  }

  static const _columns = 64;
  static const _rows = 28;
  static const _count = (_columns + 1) * (_rows + 1);
  static const _cloudRegions = <List<double>>[
    [26, 42, 35, 13],
    [111, 28, 32, 12],
    [169, 42, 26, 8],
    [283, 39, 17, 7],
    [99, 66, 24, 8],
    [23, 79, 22, 6],
    [209, 60, 30, 11],
  ];

  final _rest = Float32List(_count * 2);
  final _positions = Float32List(_count * 2);
  final _texture = Float32List(_count * 2);
  final _cloudWeight = Float32List(_count);
  final _smokeWeight = Float32List(_count);
  final _indices = Uint16List(_columns * _rows * 6);
  late final ui.ImageShader _shader;
  final _paint = ui.Paint()..isAntiAlias = false;
  double _time = 0;

  static double _influence(double x, double y, List<double> region) {
    final dx = (x - region[0]) / region[2];
    final dy = (y - region[1]) / region[3];
    final weight = math.max(0.0, 1 - dx * dx - dy * dy);
    return weight * weight;
  }

  void update(double dt) => _time += dt;

  void render(ui.Canvas canvas, double opacity) {
    if (opacity <= 0) return;
    for (var i = 0; i < _count; i++) {
      final x = _rest[i * 2];
      final y = _rest[i * 2 + 1];
      final wind = _time * 0.45 + x * 0.013;
      final billow = _time * 0.85 - y * 0.12;
      _positions[i * 2] =
          x +
          _cloudWeight[i] * math.sin(wind) * 2.2 +
          _smokeWeight[i] * math.sin(billow) * 3;
      _positions[i * 2 + 1] =
          y +
          _cloudWeight[i] * math.sin(wind * 0.8) * 0.35 +
          _smokeWeight[i] * math.cos(billow) * 0.8;
    }
    final mesh = ui.Vertices.raw(
      ui.VertexMode.triangles,
      _positions,
      textureCoordinates: _texture,
      indices: _indices,
    );
    _paint
      ..shader = _shader
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawVertices(mesh, ui.BlendMode.srcOver, _paint);
    mesh.dispose();
  }

  void dispose() => _shader.dispose();
}
