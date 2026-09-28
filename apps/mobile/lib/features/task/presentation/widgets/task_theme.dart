import 'package:flutter/material.dart';

abstract final class TaskTheme {
  static const Color deep = Color(0xFF1A0838);
  static const Color mid = Color(0xFF2C1058);
  static const Color panel = Color(0xFF3A1A72);
  static const Color panelLight = Color(0xFF4B2588);
  static const Color magenta = Color(0xFFE91E8C);
  static const Color magentaSoft = Color(0xFFFF4DA6);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF5D76E);
  static const Color goldBright = Color(0xFFFFE9A0);
  static const Color cream = Color(0xFFFFF8E7);

  static const LinearGradient pageBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3B1570), Color(0xFF1A0838), Color(0xFF12052A)],
  );

  static const LinearGradient goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF0B8), Color(0xFFE8B923), Color(0xFFB8860B)],
  );

  static const LinearGradient claimButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF6BB5), Color(0xFFE91E8C), Color(0xFFC2185B)],
  );

  static const LinearGradient dayCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A2080), Color(0xFF2A1058)],
  );

  static BoxDecoration goldBorderPanel({double radius = 22}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4B2588), Color(0xFF2C1058)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: gold.withValues(alpha: 0.85), width: 2),
      boxShadow: [
        BoxShadow(
          color: gold.withValues(alpha: 0.28),
          blurRadius: 18,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static List<Shadow> goldTitleShadows = [
    Shadow(color: gold.withValues(alpha: 0.9), blurRadius: 12),
    Shadow(color: magenta.withValues(alpha: 0.45), blurRadius: 22),
    const Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
  ];
}

class TaskStarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final sparks = <Offset>[
      Offset(size.width * 0.08, size.height * 0.06),
      Offset(size.width * 0.22, size.height * 0.14),
      Offset(size.width * 0.72, size.height * 0.05),
      Offset(size.width * 0.88, size.height * 0.12),
      Offset(size.width * 0.15, size.height * 0.32),
      Offset(size.width * 0.92, size.height * 0.28),
      Offset(size.width * 0.55, size.height * 0.18),
      Offset(size.width * 0.35, size.height * 0.08),
      Offset(size.width * 0.65, size.height * 0.40),
      Offset(size.width * 0.10, size.height * 0.55),
      Offset(size.width * 0.80, size.height * 0.62),
      Offset(size.width * 0.45, size.height * 0.72),
      Offset(size.width * 0.95, size.height * 0.78),
      Offset(size.width * 0.28, size.height * 0.88),
    ];
    for (var i = 0; i < sparks.length; i++) {
      final r = (i.isEven ? 1.2 : 1.8);
      canvas.drawCircle(sparks[i], r, paint);
    }

    final glow = Paint()
      ..color = TaskTheme.magenta.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.12), 90, glow);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      70,
      Paint()
        ..color = TaskTheme.gold.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
