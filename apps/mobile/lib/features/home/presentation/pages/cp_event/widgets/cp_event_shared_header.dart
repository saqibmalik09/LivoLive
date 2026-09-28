import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_couple_podium.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_rules_popup.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_timer.dart';

class CpEventSharedHeader extends StatelessWidget {
  const CpEventSharedHeader({
    super.key,
    required this.event,
    required this.topCouple,
    required this.tabIndex,
    required this.onTabChanged,
  });

  final PartyEvent event;
  final CpEventCoupleRank? topCouple;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 400,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color(0xCC000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.55, 0.82, 1.0],
                  ).createShader(bounds);
                },
                child: Image.asset(
                  CpEventAssets.hero,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.35),
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFB6C1), Color(0xFF7B1FA2)],
                      ),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.transparent,
                      const Color(0xFF2D0A3A).withValues(alpha: 0.35),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Image.asset(
                              CpEventAssets.backButton,
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              event.title.isNotEmpty ? event.title : 'Best CP',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                shadows: [
                                  Shadow(blurRadius: 8, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4, top: 2),
                        child: GestureDetector(
                          onTap: () => showCpEventRulesPopup(context, event),
                          child: Image.asset(
                            CpEventAssets.rulesButton,
                            height: 36,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: const Alignment(0, 0.55),
                        child: CpTop1Frame(couple: topCouple, width: 310),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        CpEventTimer(endAt: event.endAt),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _tab('CP Square', 0),
              const SizedBox(width: 8),
              _tab('Rank', 1),
              const SizedBox(width: 8),
              _tab('Reward', 2),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _tab(String label, int index) {
    final selected = tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                selected ? CpEventAssets.focusButton : CpEventAssets.button,
              ),
              fit: BoxFit.fill,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          ),
        ),
      ),
    );
  }
}
