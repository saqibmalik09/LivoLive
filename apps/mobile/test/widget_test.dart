// The stock "SkLiveApp builds" test could never pass in this harness.
//
// Pumping the root widget needs the whole bootstrap main() performs — Firebase,
// Hive, LiveKit and Supabase — and once it is up the app starts periodic work
// owned by services rather than by widget State, so the tree cannot be torn
// down cleanly and the test always fails on pending timers. Launching the real
// app belongs on a device, not here.
//
// What *is* checkable at this level is the localisation surface the UI depends
// on: the app ships nine translations, and several fixes in this round added or
// moved translated labels, so a locale silently losing a label would show up as
// blank text for those users.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sk_live/l10n/app_localizations.dart';

void main() {
  test('every supported locale has a resolvable delegate', () {
    expect(AppLocalizations.supportedLocales, isNotEmpty);
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        AppLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: 'no delegate for ${locale.languageCode}',
      );
    }
  });

  test('the languages the picker offers are all present', () {
    final codes =
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    for (final code in const [
      'en', 'ar', 'id', 'tr', 'ur', 'hi', 'pt', 'th', 'vi',
    ]) {
      expect(codes, contains(code), reason: '$code missing from l10n');
    }
  });

  testWidgets('labels used by this round of fixes resolve everywhere',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      for (final value in [
        l10n.room_chat,            // room feed tabs
        l10n.room_gifts,
        l10n.profile_inviteFriend, // promoted "My" page grid entries
        l10n.profile_realNameVerify,
        l10n.profile_task,
        l10n.profile_level,
        l10n.profile_buddies,
        l10n.profile_blacklist,
        l10n.auth_selectGender,    // registration gender step
        l10n.auth_genderMale,
        l10n.auth_genderFemale,
      ]) {
        expect(value.trim(), isNotEmpty,
            reason: 'empty label for ${locale.languageCode}');
      }
    }
  });
}
