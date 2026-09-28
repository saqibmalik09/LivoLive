import 'package:flutter/material.dart';

abstract final class InviteEarnTheme {
  static const Color deepGreen = Color(0xFF0B3D2E);
  static const Color midGreen = Color(0xFF145C40);
  static const Color lightGreen = Color(0xFF1E7A52);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF0D060);
  static const Color goldDark = Color(0xFFA67C00);
  static const Color cream = Color(0xFFFFF8E7);
  static const Color panel = Color(0xFF0F4635);

  static const LinearGradient goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5E6A3), Color(0xFFD4AF37), Color(0xFFB8860B)],
  );

  static const LinearGradient greenPanel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A6B4A), Color(0xFF0B3D2E)],
  );

  static BoxDecoration goldBorderCard({double radius = 18}) {
    return BoxDecoration(
      gradient: greenPanel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: gold, width: 2.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration pill({required Color fill, Color? border}) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border ?? gold, width: 1.4),
    );
  }
}
