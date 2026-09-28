import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_my_rank_bar.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_rank_tab.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_reward_tab.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_shared_header.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_square_tab.dart';
import 'package:sk_live/features/home/presentation/pages/cp_nest_screen.dart';
import 'package:sk_live/features/home/presentation/pages/party_event_content.dart';

class CpEventScreen extends ConsumerStatefulWidget {
  const CpEventScreen({super.key, required this.event});

  final PartyEvent event;

  @override
  ConsumerState<CpEventScreen> createState() => _CpEventScreenState();
}

class _CpEventScreenState extends ConsumerState<CpEventScreen> {
  int _tabIndex = 1;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankingsAsync = ref.watch(
      cpEventTopRankingsProvider(widget.event.id),
    );
    final myRankAsync = ref.watch(myCpEventRankProvider(widget.event.id));
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final content = PartyEventContent.fromEvent(widget.event);
    final topCouple = rankingsAsync.valueOrNull?.isNotEmpty == true
        ? rankingsAsync.valueOrNull!.first
        : null;
    final screenH = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFF2D0A3A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: screenH * 0.32,
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
                CpEventAssets.background,
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
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: CpEventSharedHeader(
                        event: widget.event,
                        topCouple: topCouple,
                        tabIndex: _tabIndex,
                        onTabChanged: (i) => setState(() => _tabIndex = i),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey(_tabIndex),
                          child: _buildTabBody(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_tabIndex == 1)
                CpEventMyRankBar(
                  me: myRankAsync.valueOrNull,
                  fallbackName: profile?['username']?.toString(),
                  fallbackAvatar: profile?['avatar_url']?.toString(),
                ),
              if (_tabIndex != 1)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CPNestScreen(),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4081),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          content.ctaLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_tabIndex) {
      case 0:
        return CpEventSquareTab(event: widget.event);
      case 2:
        return CpEventRewardTab(event: widget.event);
      case 1:
      default:
        return CpEventRankTab(
          event: widget.event,
          scrollController: _scrollController,
        );
    }
  }
}
