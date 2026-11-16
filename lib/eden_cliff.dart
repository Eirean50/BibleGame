import 'package:flutter/painting.dart';

/// A solid pixel-art overlook, drawn in the same world space as the figures.
/// The rock continues below the viewport so the ledge connects to the hillside.
void drawEdenCliff(Canvas canvas, Rect group) {
  final unit = group.width * 1.45 / 160;
  final paint = Paint()..isAntiAlias = false;
  canvas.save();
  canvas.translate(group.center.dx - 80 * unit, group.bottom - 12 * unit);
  canvas.scale(unit);

  void shape(int color, List<Offset> points) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, paint..color = Color(color));
  }

  void block(int color, double x, double y, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint..color = Color(color));
  }

  // Stepped silhouette and vertical rock strata, with no translucent backing.
  shape(0xFF39463D, const [
    Offset(0, 12),
    Offset(12, 12),
    Offset(12, 5),
    Offset(38, 5),
    Offset(38, 0),
    Offset(121, 0),
    Offset(121, 4),
    Offset(146, 4),
    Offset(146, 10),
    Offset(160, 10),
    Offset(160, 38),
    Offset(154, 38),
    Offset(154, 65),
    Offset(164, 65),
    Offset(164, 110),
    Offset(-8, 110),
    Offset(-8, 66),
    Offset(5, 66),
    Offset(5, 35),
    Offset(0, 35),
  ]);
  shape(0xFF77765B, const [
    Offset(9, 20),
    Offset(62, 24),
    Offset(62, 38),
    Offset(53, 38),
    Offset(53, 60),
    Offset(43, 60),
    Offset(43, 110),
    Offset(2, 110),
    Offset(2, 70),
    Offset(13, 70),
    Offset(13, 43),
    Offset(9, 43),
  ]);
  shape(0xFF9A906B, const [
    Offset(15, 23),
    Offset(47, 27),
    Offset(47, 37),
    Offset(39, 37),
    Offset(39, 58),
    Offset(32, 58),
    Offset(32, 86),
    Offset(20, 86),
    Offset(20, 48),
    Offset(15, 48),
  ]);
  shape(0xFF5C6550, const [
    Offset(68, 23),
    Offset(111, 23),
    Offset(111, 47),
    Offset(102, 47),
    Offset(102, 74),
    Offset(113, 74),
    Offset(113, 110),
    Offset(54, 110),
    Offset(54, 65),
    Offset(63, 65),
    Offset(63, 43),
    Offset(68, 43),
  ]);
  shape(0xFF495443, const [
    Offset(122, 20),
    Offset(154, 17),
    Offset(154, 35),
    Offset(147, 35),
    Offset(147, 64),
    Offset(155, 64),
    Offset(155, 110),
    Offset(119, 110),
    Offset(119, 69),
    Offset(127, 69),
    Offset(127, 43),
    Offset(122, 43),
  ]);
  block(0xFFB0A17B, 19, 30, 23, 3);
  block(0xFF39463D, 32, 51, 17, 3);
  block(0xFF87906A, 73, 32, 24, 4);
  block(0xFF39463D, 71, 55, 31, 3);
  block(0xFF737A5C, 133, 39, 13, 3);

  // Broad grassy surface underneath every pose's feet.
  shape(0xFF41613B, const [
    Offset(0, 12),
    Offset(12, 12),
    Offset(12, 5),
    Offset(38, 5),
    Offset(38, 0),
    Offset(121, 0),
    Offset(121, 4),
    Offset(146, 4),
    Offset(146, 10),
    Offset(160, 10),
    Offset(160, 18),
    Offset(143, 18),
    Offset(143, 24),
    Offset(114, 24),
    Offset(114, 28),
    Offset(52, 28),
    Offset(52, 25),
    Offset(21, 25),
    Offset(21, 21),
    Offset(0, 21),
  ]);
  shape(0xFF71934D, const [
    Offset(6, 12),
    Offset(19, 12),
    Offset(19, 7),
    Offset(42, 7),
    Offset(42, 3),
    Offset(117, 3),
    Offset(117, 7),
    Offset(141, 7),
    Offset(141, 12),
    Offset(154, 12),
    Offset(154, 16),
    Offset(137, 16),
    Offset(137, 20),
    Offset(109, 20),
    Offset(109, 23),
    Offset(55, 23),
    Offset(55, 20),
    Offset(26, 20),
    Offset(26, 17),
    Offset(6, 17),
  ]);
  for (var i = 0; i < 30; i++) {
    final x = 16.0 + (i * 29 % 124);
    final y = 7.0 + (i * 7 % 11);
    block(i.isEven ? 0xFF91AA60 : 0xFF587743, x, y, 3 + i % 4.0, 2);
  }
  // Moss hangs over the lip; roots tie the grass into the rock face.
  for (final x in [24.0, 54.0, 103.0, 136.0]) {
    block(0xFF41613B, x, 21, 5, 12);
    block(0xFF658447, x, 21, 2, 8);
  }
  canvas.restore();

  // Small contact shadows follow the feet, rather than one floating oval.
  for (final x in [0.13, 0.44, 0.79]) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          group.left + group.width * x,
          group.bottom - group.height * 0.018,
        ),
        width: group.width * 0.15,
        height: group.height * 0.022,
      ),
      paint..color = const Color(0xFF384D30),
    );
  }
}
