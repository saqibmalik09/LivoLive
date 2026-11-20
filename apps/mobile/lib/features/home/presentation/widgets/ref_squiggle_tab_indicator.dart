import 'package:flutter/material.dart';

class RefSquiggleTabIndicator extends Decoration {
  const RefSquiggleTabIndicator({
    required this.width,
    required this.height,
    required this.belowCenter,
    this.color = Colors.white,
  });

  final double width;
  final double height;

  final double belowCenter;
  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _SquigglePainter(this, onChanged);
}

class _SquigglePainter extends BoxPainter {
  _SquigglePainter(this.d, super.onChanged);

  final RefSquiggleTabIndicator d;

  static const List<Offset> _points = [
    Offset(0.00, 0.23),
    Offset(0.48, 0.03),
    Offset(0.51, 0.43),
    Offset(0.98, 0.10),
    Offset(1.00, 0.47),
    Offset(0.45, 1.00),
    Offset(0.39, 0.47),
    Offset(0.01, 0.60),
  ];

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final left = rect.center.dx - d.width / 2;
    final top = rect.center.dy + d.belowCenter;
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final p = Offset(
        left + _points[i].dx * d.width,
        top + _points[i].dy * d.height,
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = d.color
        ..isAntiAlias = true,
    );
  }
}
