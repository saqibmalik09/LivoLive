import 'package:flutter/material.dart';
import 'package:sk_live/l10n/app_localizations.dart';

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String navLabel(String navKey, String storedLabel) {
    final l = l10n;
    switch (navKey) {
      case 'home':
        return l.nav_home;
      case 'party':
        return l.nav_party;
      case 'game':
        return l.nav_game;
      case 'message':
        return l.nav_message;
      case 'my':
        return l.nav_my;
      default:
        return storedLabel.isNotEmpty ? storedLabel : l.nav_tabFallback;
    }
  }
}
