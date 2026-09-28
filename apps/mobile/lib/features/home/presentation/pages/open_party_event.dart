import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event_screen.dart';
import 'package:sk_live/features/home/presentation/pages/event_webview_screen.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_event_screen.dart';
import 'package:sk_live/features/home/presentation/pages/sk_party/sk_party_event_screen.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_event_screen.dart';

void openPartyEvent(BuildContext context, PartyEvent event) {
  final Widget screen = switch (event.eventKind) {
    PartyEventKind.cpNative => CpEventScreen(event: event),
    PartyEventKind.weeklyStarNative => WeeklyStarEventScreen(event: event),
    PartyEventKind.gameStarNative => GameStarEventScreen(event: event),
    PartyEventKind.skHostNative => SkPartyEventScreen(event: event),
    PartyEventKind.webview => EventWebViewScreen(event: event),
  };

  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}
