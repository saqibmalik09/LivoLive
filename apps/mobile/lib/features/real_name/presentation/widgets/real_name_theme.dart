import 'package:flutter/material.dart';

abstract final class RealNameTheme {
  static const Color bg = Color(0xFFF5F7FA);
  static const Color card = Colors.white;
  static const Color primary = Color(0xFF2F80ED);
  static const Color primaryDark = Color(0xFF1B5BB8);
  static const Color heroBlue = Color(0xFFE8F1FF);
  static const Color text = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color warningBg = Color(0xFFFFE8E8);
  static const Color warningText = Color(0xFFD32F2F);
  static const Color border = Color(0xFFE5E7EB);
  static const Color fail = Color(0xFFE53935);
  static const Color success = Color(0xFF22C55E);

  static ThemeData light(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
    );
  }
}
