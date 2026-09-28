import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_couple_podium.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_event_rank_list_tile.dart';
import 'package:sk_live/features/home/presentation/pages/party_event_content.dart';

class CpEventRankTab extends ConsumerStatefulWidget {
  const CpEventRankTab({
    super.key,
    required this.event,
    required this.scrollController,
  });

  final PartyEvent event;
  final ScrollController scrollController;

  @override
  ConsumerState<CpEventRankTab> createState() => _CpEventRankTabState();
}

class _CpEventRankTabState extends ConsumerState<CpEventRankTab> {
  final List<CpEventCoupleRank> _extra = [];
  int _page = 0;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    final c = widget.scrollController;
    if (!c.hasClients) return;
    if (c.position.pixels >= c.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final page = await ref.read(
      cpEventRankingsPageProvider((widget.event.id, _page)).future,
    );
    if (!mounted) return;
    setState(() {
      _extra.addAll(page);
      _page += 1;
      _hasMore = page.length >= 20;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = PartyEventContent.fromEvent(widget.event);
    final rankingsAsync = ref.watch(
      cpEventTopRankingsProvider(widget.event.id),
    );

    return rankingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: Colors.pinkAccent),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load rankings: $e',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      data: (all) {
        final top1 = all.isNotEmpty ? all[0] : null;
        final top2 = all.length > 1 ? all[1] : null;
        final top3 = all.length > 2 ? all[2] : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB6C1).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  content.rules.isNotEmpty
                      ? content.rules
                      : 'Once a CP relationship is successfully formed, rankings are determined based on the total amount of coins both parties receive from CP-exclusive gifts. (1 coin spent on CP gifts = 1 intimacy point).',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (top1 != null || top2 != null || top3 != null)
                CpTop3Board(top1: top1, top2: top2, top3: top3),
              const SizedBox(height: 16),
              if (_extra.isEmpty && !_loadingMore && all.length <= 3)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No more couples on the board yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ..._extra.map((c) => CpEventRankListTile(couple: c)),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.pinkAccent),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
