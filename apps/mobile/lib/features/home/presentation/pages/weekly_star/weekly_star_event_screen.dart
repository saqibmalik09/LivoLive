import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/providers/weekly_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_assets.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/widgets/weekly_star_gifts_rules.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/widgets/weekly_star_header.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/widgets/weekly_star_my_rank_bar.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/widgets/weekly_star_rank_tab.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/widgets/weekly_star_reward_tab.dart';

class WeeklyStarEventScreen extends ConsumerStatefulWidget {
  const WeeklyStarEventScreen({super.key, required this.event});

  final PartyEvent event;

  @override
  ConsumerState<WeeklyStarEventScreen> createState() =>
      _WeeklyStarEventScreenState();
}

class _WeeklyStarEventScreenState extends ConsumerState<WeeklyStarEventScreen> {
  int _tabIndex = 1;

  String get _periodKey => _tabIndex == 0 ? 'last' : 'current';

  @override
  Widget build(BuildContext context) {
    final winnerAsync = ref.watch(
      weeklyStarLastWeekWinnerProvider(widget.event.id),
    );
    final myRankAsync = ref.watch(
      myWeeklyStarRankProvider((
        eventId: widget.event.id,
        periodKey: _periodKey,
      )),
    );
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final screenH = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0618),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: screenH * 0.28,
            left: 0,
            right: 0,
            bottom: 0,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xCC000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x99000000),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.12, 0.28, 0.72, 0.9, 1.0],
                ).createShader(bounds);
              },
              child: Image.asset(
                WeeklyStarAssets.background,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: WeeklyStarHeader(
                        title: widget.event.title.isNotEmpty
                            ? widget.event.title
                            : context.l10n.event_shiningStarLastWeek,
                        endAt: widget.event.endAt,
                        winner: winnerAsync.valueOrNull,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: WeeklyStarGiftsRules(event: widget.event),
                    ),
                    SliverToBoxAdapter(child: _tabs()),
                    SliverToBoxAdapter(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey(_tabIndex),
                          child: _buildTabBody(),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ],
                ),
              ),
              if (_tabIndex != 2)
                WeeklyStarMyRankBar(
                  me: myRankAsync.valueOrNull,
                  fallbackName: profile?['username']?.toString(),
                  fallbackAvatar: profile?['avatar_url']?.toString(),
                  fallbackShortId: profile?['short_id']?.toString(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          _tabBtn('Last Week', 0),
          const SizedBox(width: 8),
          _tabBtn('This Week', 1),
          const SizedBox(width: 8),
          _tabBtn('Reward', 2),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                selected
                    ? WeeklyStarAssets.focusButton
                    : WeeklyStarAssets.button,
              ),
              fit: BoxFit.fill,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_tabIndex) {
      case 0:
        return WeeklyStarRankTab(
          eventId: widget.event.id,
          periodKey: 'last',
          title: context.l10n.event_lastWeekList,
        );
      case 2:
        return WeeklyStarRewardTab(event: widget.event);
      case 1:
      default:
        return WeeklyStarRankTab(
          eventId: widget.event.id,
          periodKey: 'current',
          title: 'This Week List',
        );
    }
  }
}
