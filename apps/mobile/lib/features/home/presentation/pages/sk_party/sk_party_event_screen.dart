import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/sk_host_party_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/sk_party/sk_party_assets.dart';
import 'package:sk_live/features/home/presentation/pages/sk_party/sk_party_tiers.dart';

class SkPartyEventScreen extends ConsumerStatefulWidget {
  const SkPartyEventScreen({super.key, required this.event});

  final PartyEvent event;

  @override
  ConsumerState<SkPartyEventScreen> createState() => _SkPartyEventScreenState();
}

class _SkPartyEventScreenState extends ConsumerState<SkPartyEventScreen> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final progress = ref
        .read(skHostProgressProvider(widget.event.id))
        .valueOrNull;
    final end = progress?.periodEnd ?? _fallbackPhaseEnd();
    final diff = end.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  DateTime _fallbackPhaseEnd() {
    final now = DateTime.now();
    final eventEnd = widget.event.endAt?.toLocal();
    DateTime phaseEnd;
    if (now.day <= 15) {
      phaseEnd = DateTime(now.year, now.month, 15, 23, 59, 59);
    } else {
      final last = DateTime(now.year, now.month + 1, 0);
      phaseEnd = DateTime(last.year, last.month, last.day, 23, 59, 59);
    }
    if (eventEnd != null && eventEnd.isBefore(phaseEnd)) return eventEnd;
    return phaseEnd;
  }

  String _periodLabel(SkHostProgress? p) {
    if (p != null) {
      final s = p.periodStart;
      final e = p.periodEnd;
      return 'Event phase (${s.year}-${s.month}-${s.day}--${e.day})';
    }
    final now = DateTime.now();
    if (now.day <= 15) {
      return 'Event phase (${now.year}-${now.month}-1--15)';
    }
    final last = DateTime(now.year, now.month + 1, 0).day;
    return 'Event phase (${now.year}-${now.month}-16--$last)';
  }

  Future<void> _onReceive() async {
    final progress = ref
        .read(skHostProgressProvider(widget.event.id))
        .valueOrNull;
    if (progress == null || !progress.canClaim) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.event_noRewardLastPeriod)),
      );
      return;
    }

    setState(() => _claiming = true);
    try {
      final res = await claimSkHostPartyReward(widget.event.id);
      if (!mounted) return;
      if (res['success'] == true) {
        final coins = (res['coin_amount'] as num?)?.toInt() ?? 0;
        final level = (res['level'] as num?)?.toInt() ?? 0;
        ref.invalidate(skHostProgressProvider(widget.event.id));
        ref.invalidate(userProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Received ${_fmt(coins)} coins from last period (LV$level).',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? context.l10n.reward_claimFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.reward_claimFailed}: $e')),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event.title.isNotEmpty
        ? widget.event.title
        : context.l10n.event_skHostParty;
    final screenH = MediaQuery.sizeOf(context).height;
    final async = ref.watch(skHostProgressProvider(widget.event.id));

    return Scaffold(
      backgroundColor: const Color(0xFF06101F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: screenH * 0.18,
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
                SkPartyAssets.background,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          SafeArea(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to load host progress.\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          skHostProgressProvider(widget.event.id),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (progress) {
                final tiers = progress?.tiers.isNotEmpty == true
                    ? progress!.tiers
                    : (parseSkHostTiers(widget.event.actionConfig) ??
                          defaultSkHostTiers());
                final level = progress?.level ?? 0;
                final next = progress?.nextTier;
                final rules = (progress?.rules.trim().isNotEmpty == true)
                    ? progress!.rules
                    : ((widget.event.actionConfig['rules'] as String?)
                                  ?.trim()
                                  .isNotEmpty ==
                              true
                          ? widget.event.actionConfig['rules'] as String
                          : defaultSkHostRules());

                return RefreshIndicator(
                  color: const Color(0xFFFFD54F),
                  onRefresh: () async {
                    ref.invalidate(skHostProgressProvider(widget.event.id));
                    await ref.read(
                      skHostProgressProvider(widget.event.id).future,
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _header(title)),
                      SliverToBoxAdapter(child: _banner()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            children: [
                              _phaseBlock(_periodLabel(progress)),
                              const SizedBox(height: 12),
                              _myDataCard(
                                progress: progress,
                                level: level,
                                next: next,
                              ),
                              const SizedBox(height: 12),
                              _rewardsTable(tiers),
                              const SizedBox(height: 12),
                              _rulesCard(rules),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                shadows: [Shadow(blurRadius: 8, color: Color(0xAA1565C0))],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ref.invalidate(skHostProgressProvider(widget.event.id));
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(
            SkPartyAssets.banner,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFF0D1B2A),
              alignment: Alignment.center,
              child: const Text(
                'LIVO\nHOST EVENT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phaseBlock(String label) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xCC0A1628),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66FFD54F)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3949AB).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _countdownRow(),
        ],
      ),
    );
  }

  Widget _myDataCard({
    required SkHostProgress? progress,
    required int level,
    required SkHostTier? next,
  }) {
    final charms = progress?.charms ?? 0;
    final workDays = progress?.workDays ?? 0;
    final workHours = progress?.workHours ?? 0;
    final lastCharms = progress?.lastCharms ?? 0;
    final lastWorkDays = progress?.lastWorkDays ?? 0;
    final lastLevel = progress?.lastLevel ?? 0;
    final lastCoin = progress?.lastCoinReward ?? 0;
    final canReceive = progress?.canClaim == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xE00A1A32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x5542A5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('My Data'),
          const SizedBox(height: 8),
          _kvRow([
            ('Charms', _fmt(charms)),
            ('Level', 'LV$level'),
            ('Work Time', '$workDays Days / ${workHours.toStringAsFixed(1)}H'),
          ]),
          const SizedBox(height: 14),
          _sectionTitle('About To Complete'),
          const SizedBox(height: 8),
          if (next == null)
            const Text(
              'Max level reached for this cycle.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            )
          else
            _kvColumn([
              ('Estimated Revenue', _fmt(next.coinReward)),
              ('Level Target', 'LV${next.level}'),
              ('Work Time Target', '${next.days} Days / ${next.hours}H'),
              ('Charm Target', _fmt(next.charms)),
            ]),
          const SizedBox(height: 14),
          _sectionTitle('Last Data'),
          const SizedBox(height: 8),
          _kvColumn([
            ('Charms', _fmt(lastCharms)),
            ('Work Time', '$lastWorkDays Days'),
            ('Previous cycle', 'LV$lastLevel'),
            ('Coin Reward', _fmt(lastCoin)),
            (
              'Status',
              progress == null
                  ? '—'
                  : (progress.lastClaimed
                        ? 'Claimed'
                        : (canReceive ? 'Ready to claim' : 'Not eligible')),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: canReceive
                      ? const [Color(0xFFFFE082), Color(0xFFB8860B)]
                      : const [Color(0xFF5C6BC0), Color(0xFF37474F)],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _claiming ? null : _onReceive,
                  child: Center(
                    child: _claiming
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            canReceive ? 'Receive' : 'Receive',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This reward is for the last activity period.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF90CAF9).withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardsTable(List<SkHostTier> tiers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xE0081428),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x445C6BC0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF3949AB),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: const Row(
              children: [
                _Th('Level', flex: 2),
                _Th('Charms', flex: 3),
                _Th('New Host Rewards(Coins)', flex: 4),
                _Th('Days/Hours', flex: 3),
              ],
            ),
          ),
          for (var i = 0; i < tiers.length; i++)
            Container(
              color: i.isEven
                  ? const Color(0xFF0D213F)
                  : const Color(0xFF123056),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
              child: Row(
                children: [
                  _Td('LV${tiers[i].level}', flex: 2),
                  _Td(_fmt(tiers[i].charms), flex: 3),
                  _Td(_fmt(tiers[i].coinReward), flex: 4),
                  _Td('${tiers[i].days}D/${tiers[i].hours}H', flex: 3),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _rulesCard(String rules) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0x99081020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.reward_rules,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            rules.trim(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFFFD54F),
        fontWeight: FontWeight.w900,
        fontSize: 15,
      ),
    );
  }

  Widget _kvRow(List<(String, String)> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final item in items)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${item.$1}: ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: item.$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _kvColumn(List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${item.$1}: ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: item.$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _countdownRow() {
    final d = _remaining.inDays;
    final h = _remaining.inHours.remainder(24);
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    return Row(
      children: [
        _box(d, 'Days'),
        const SizedBox(width: 8),
        _box(h, 'Hours'),
        const SizedBox(width: 8),
        _box(m, 'Min'),
        const SizedBox(width: 8),
        _box(s, 'Sec'),
      ],
    );
  }

  Widget _box(int value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5C6BC0), Color(0xFF283593)],
          ),
          border: Border.all(color: const Color(0xAAFFD54F)),
        ),
        child: Column(
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text, {required this.flex});
  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  const _Td(this.text, {required this.flex});
  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String defaultSkHostRules() {
  final now = DateTime.now();
  return '''
1. Hosts must meet both broadcast time and charm targets to receive rewards.
2. Hosts must manually claim prizes after each activity period.
3. Cycles run from the 1st–15th and 16th–end of each month. Data resets after each cycle.
4. Event dates follow the active party event window in Livo.
5. Final interpretation belongs to Livo (${now.year}).
''';
}
