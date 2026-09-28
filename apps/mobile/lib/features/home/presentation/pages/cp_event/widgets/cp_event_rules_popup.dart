import 'package:flutter/material.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/party_event_content.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';

const String _defaultCpRules = '''
1. Only users with an established CP bond can join the ranking list. Rankings are determined by the total Coins both parties receive from exclusive CP gifts.

2. Spending 1 Coin to send an exclusive CP gift will add 1 Intimacy Point to both users.

3. Ranking points refresh in real time. The final ranking is based on the list data at the moment the event ends.

Rewards will be automatically distributed by the system after the event concludes.
''';

void showCpEventRulesPopup(BuildContext context, PartyEvent event) {
  final content = PartyEventContent.fromEvent(event);
  final rulesText = content.rules.trim().isNotEmpty
      ? content.rules.trim()
      : _defaultCpRules;

  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) {
      final w = MediaQuery.sizeOf(ctx).width * 0.88;
      final h = w * (432 / 294);

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SizedBox(
          width: w,
          height: h.clamp(360.0, MediaQuery.sizeOf(ctx).height * 0.75),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(CpEventAssets.rulesImage, fit: BoxFit.fill),
              ),
              Positioned(
                left: w * 0.22,
                top: h * 0.045,
                width: w * 0.56,
                height: h * 0.07,
                child: const Center(
                  child: Text(
                    'Rules',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 3, color: Colors.black45)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: w * 0.10,
                right: w * 0.10,
                top: h * 0.16,
                bottom: h * 0.08,
                child: SingleChildScrollView(
                  child: Text(
                    rulesText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black38)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
