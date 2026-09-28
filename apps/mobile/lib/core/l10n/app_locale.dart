import 'package:flutter/material.dart';

abstract final class AppLocale {
  static const String prefsKey = 'app_locale_code';
  static const String defaultCode = 'en';

  static const List<Locale> supported = [
    Locale('en'),
    Locale('ar'),
    Locale('id'),
    Locale('tr'),
    Locale('ur'),
    Locale('hi'),
    Locale('pt'),
    Locale('th'),
    Locale('vi'),
  ];

  static const List<String> codes = [
    'en',
    'ar',
    'id',
    'tr',
    'ur',
    'hi',
    'pt',
    'th',
    'vi',
  ];

  static Locale resolve(String? code) {
    final c = (code ?? defaultCode).trim().toLowerCase();
    if (codes.contains(c)) return Locale(c);
    return const Locale(defaultCode);
  }

  static bool isRtl(String code) => code == 'ar' || code == 'ur';
}
