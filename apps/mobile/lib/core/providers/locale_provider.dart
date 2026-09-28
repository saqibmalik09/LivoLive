import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/l10n/app_locale.dart';

final localeProvider = StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController();
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(const Locale(AppLocale.defaultCode)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(AppLocale.prefsKey);
      state = AppLocale.resolve(code);
    } catch (_) {
      state = const Locale(AppLocale.defaultCode);
    }
  }

  Future<void> setLocaleCode(String code) async {
    final locale = AppLocale.resolve(code);
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppLocale.prefsKey, locale.languageCode);
    } catch (_) {}
  }
}
