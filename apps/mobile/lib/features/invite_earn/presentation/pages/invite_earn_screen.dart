import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/invite_download_url_provider.dart';
import 'package:sk_live/features/invite_earn/data/invite_earn_config.dart';
import 'package:sk_live/features/invite_earn/data/invite_earn_provider.dart';
import 'package:sk_live/features/invite_earn/presentation/widgets/invite_earn_theme.dart';
import 'package:sk_live/features/invite_earn/presentation/widgets/invite_earn_wheel.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class InviteEarnScreen extends ConsumerStatefulWidget {
  const InviteEarnScreen({super.key, required this.inviteCode});

  final String inviteCode;

  @override
  ConsumerState<InviteEarnScreen> createState() => _InviteEarnScreenState();
}

class _InviteEarnScreenState extends ConsumerState<InviteEarnScreen> {
  int _tab = 0;
  bool _claiming = false;
  bool _spinning = false;

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.invite_codeCopied)));
  }

  Future<void> _shareInvite(String code) async {
    final downloadUrl =
        ref.read(inviteDownloadUrlProvider).valueOrNull ??
        InviteEarnConfig.downloadUrl;
    await Share.share(
      'Join Livo! Use my invitation code $code when you sign up. '
      'Download: $downloadUrl',
    );
  }

  void _showRules() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: InviteEarnTheme.deepGreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: InviteEarnTheme.gold.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.invite_rules,
                style: const TextStyle(
                  color: InviteEarnTheme.goldLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...InviteEarnConfig.rules.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(color: InviteEarnTheme.gold),
                      ),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            color: InviteEarnTheme.cream,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _claimMilestone(int invitesNeeded) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final res = await claimInviteMilestone(invitesNeeded);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+${res['reward_coins']} coins claimed!')),
        );
        ref.invalidate(inviteEarnSummaryProvider);
        ref.invalidate(userProfileProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? context.l10n.reward_claimFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<Map<String, dynamic>> _onSpin() async {
    if (_spinning) return {'success': false, 'message': 'Busy'};
    setState(() => _spinning = true);
    try {
      final res = await spinInviteWheel();
      if (!mounted) return res;
      if (res['success'] == true) {
        final coins = res['reward_coins'];
        final label = res['label'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              coins != null && (coins as num) > 0
                  ? 'You won $label (+$coins coins)!'
                  : 'Result: $label',
            ),
          ),
        );
        ref.invalidate(inviteEarnSummaryProvider);
        ref.invalidate(userProfileProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Spin failed')),
        );
      }
      return res;
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final summaryAsync = ref.watch(inviteEarnSummaryProvider);
    ref.watch(inviteDownloadUrlProvider);

    return Scaffold(
      backgroundColor: InviteEarnTheme.deepGreen,
      body: Stack(
        children: [
          summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => asyncErrorWidget(
              e,
              style: const TextStyle(color: Colors.white),
            ),
            data: (summary) {
              final code = summary.shortId.isNotEmpty
                  ? summary.shortId
                  : widget.inviteCode;
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHero(top, code)),
                  SoftPad(
                    child: Column(
                      children: [
                        _buildCodeCard(code),
                        const SizedBox(height: 16),
                        _buildBonusRow(),
                        const SizedBox(height: 18),
                        _buildTabs(),
                        const SizedBox(height: 14),
                        if (_tab == 0)
                          ..._rewardBody(summary)
                        else
                          _recordsBody(summary),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            child: _InviteCtaButton(
              onTap: () {
                final code = ref
                    .read(inviteEarnSummaryProvider)
                    .valueOrNull
                    ?.shortId;
                _shareInvite(
                  (code != null && code.isNotEmpty) ? code : widget.inviteCode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(double topInset, String code) {
    return SizedBox(
      height: 280 + topInset * 0.2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            InviteEarnConfig.heroAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E7A52), Color(0xFF0B3D2E)],
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
                  Colors.black.withValues(alpha: 0.15),
                  InviteEarnTheme.deepGreen.withValues(alpha: 0.55),
                  InviteEarnTheme.deepGreen,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            top: topInset + 4,
            left: 8,
            right: 8,
            child: Row(
              children: [
                _ChipButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  label: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                _ChipButton(
                  label: context.l10n.invite_rules,
                  onTap: _showRules,
                ),
                const SizedBox(width: 8),
                _ChipButton(label: 'Invite', onTap: () => _shareInvite(code)),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Column(
              children: [
                Text(
                  context.l10n.invite_title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [
                          Color(0xFFFFF3C4),
                          Color(0xFFD4AF37),
                          Color(0xFFFFE08A),
                        ],
                      ).createShader(const Rect.fromLTWH(0, 0, 320, 40)),
                    shadows: const [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: InviteEarnTheme.pill(
                    fill: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: const Text(
                    InviteEarnConfig.dateRangeLabel,
                    style: TextStyle(
                      color: InviteEarnTheme.goldLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: InviteEarnTheme.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Text(
                    'Invite friends with your code — earn coins, milestones & lucky draws',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: InviteEarnTheme.cream,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(String code) {
    return Container(
      decoration: InviteEarnTheme.goldBorderCard(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: InviteEarnTheme.goldButton,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'My Invitation Code',
              style: TextStyle(
                color: Color(0xFF3B2500),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: InviteEarnTheme.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: InviteEarnTheme.goldLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _copyCode(code),
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: InviteEarnTheme.goldButton,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Iconsax.copy, size: 18, color: Color(0xFF3B2500)),
                        SizedBox(width: 6),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Color(0xFF3B2500),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

  Widget _buildBonusRow() {
    return const Row(
      children: [
        Expanded(
          child: _BonusTile(
            value: InviteEarnConfig.weeklyBonusLabel,
            caption: InviteEarnConfig.weeklyBonusCaption,
            icon: Iconsax.cup,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _BonusTile(
            value: InviteEarnConfig.firstRechargeLabel,
            caption: InviteEarnConfig.firstRechargeCaption,
            icon: Iconsax.gift,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _BonusTile(
            value: InviteEarnConfig.everyRechargeLabel,
            caption: InviteEarnConfig.everyRechargeCaption,
            icon: Iconsax.coin,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: InviteEarnTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: 'Reward',
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
          ),
          Expanded(
            child: _TabPill(
              label: context.l10n.invite_records,
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rewardBody(InviteEarnSummary summary) {
    final filledSlots =
        (summary.weekInvites.clamp(0, InviteEarnConfig.prizeChanceFriendCap) /
                2)
            .ceil();
    return [
      _buildSteps(),
      const SizedBox(height: 12),
      Center(child: InviteEarnCountdown(endsAt: InviteEarnConfig.endsAt)),
      const SizedBox(height: 8),
      Text(
        'Total invites: ${summary.totalInvites}  ·  This week: ${summary.weekInvites}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: InviteEarnTheme.cream,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 16),
      _buildMilestones(summary),
      const SizedBox(height: 16),
      _buildPrizeChances(filledSlots),
      const SizedBox(height: 20),
      InviteLuckyWheel(
        remainingDraws: summary.wheelDraws,
        onSpin: _onSpin,
        onEmptyDraw: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.invite_noDraws)));
        },
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _recordsBody(InviteEarnSummary summary) {
    if (summary.records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: InviteEarnTheme.goldBorderCard(radius: 16),
        child: const Column(
          children: [
            Icon(Iconsax.document_text, color: InviteEarnTheme.gold, size: 40),
            SizedBox(height: 12),
            Text(
              'No invite records yet',
              style: TextStyle(
                color: InviteEarnTheme.cream,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'When friends join with your code, history will show here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Column(
      children: summary.records.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: InviteEarnTheme.goldBorderCard(radius: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: r.avatarUrl != null && r.avatarUrl!.isNotEmpty
                    ? NetworkImage(r.avatarUrl!)
                    : null,
                child: r.avatarUrl == null || r.avatarUrl!.isEmpty
                    ? const Icon(Iconsax.user, color: Colors.white70)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.username,
                      style: const TextStyle(
                        color: InviteEarnTheme.cream,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'ID ${r.shortId ?? '-'} · +${r.bonusCoins} coins',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${r.createdAt.month}/${r.createdAt.day}',
                style: const TextStyle(
                  color: InviteEarnTheme.goldLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSteps() {
    const steps = [
      ('1', 'Invite Friends'),
      ('2', 'Registration Success'),
      ('3', 'Receive Reward'),
    ];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: InviteEarnTheme.gold.withValues(alpha: 0.5),
              ),
            ),
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: InviteEarnTheme.goldButton,
                ),
                child: Text(
                  steps[i].$1,
                  style: const TextStyle(
                    color: Color(0xFF3B2500),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 88,
                child: Text(
                  steps[i].$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: InviteEarnTheme.cream,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMilestones(InviteEarnSummary summary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: InviteEarnTheme.goldBorderCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite milestones',
            style: TextStyle(
              color: InviteEarnTheme.goldLight,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: InviteEarnConfig.milestones.map((m) {
              final claimed = summary.claimedMilestones.contains(
                m.invitesNeeded,
              );
              final unlocked = summary.totalInvites >= m.invitesNeeded;
              return GestureDetector(
                onTap: claimed || !unlocked || _claiming
                    ? null
                    : () => _claimMilestone(m.invitesNeeded),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: claimed || unlocked
                              ? InviteEarnTheme.goldButton
                              : null,
                          color: claimed || unlocked
                              ? null
                              : Colors.black.withValues(alpha: 0.3),
                          border: Border.all(
                            color: InviteEarnTheme.goldLight,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              claimed ? Iconsax.tick_circle : Iconsax.coin_1,
                              size: 16,
                              color: const Color(0xFF3B2500),
                            ),
                            Text(
                              m.coinsLabel,
                              style: const TextStyle(
                                color: Color(0xFF3B2500),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        claimed
                            ? 'Claimed'
                            : unlocked
                            ? 'Tap claim\n${m.invitesNeeded}'
                            : 'Invite\n${m.invitesNeeded}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: InviteEarnTheme.cream,
                          fontSize: 10,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeChances(int filled) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: InviteEarnTheme.goldBorderCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The first ${InviteEarnConfig.prizeChanceFriendCap} friends invited this week '
            'unlock ${InviteEarnConfig.prizeChancesPerFriend} lucky draws each.',
            style: const TextStyle(
              color: InviteEarnTheme.cream,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(InviteEarnConfig.prizeChanceSlots, (i) {
              final active = i < filled;
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? InviteEarnTheme.gold.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.25),
                  border: Border.all(color: InviteEarnTheme.gold, width: 1.5),
                ),
                child: Icon(
                  active ? Iconsax.ticket_star : Icons.add,
                  color: InviteEarnTheme.goldLight,
                  size: 20,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class SoftPad extends StatelessWidget {
  const SoftPad({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: InviteEarnTheme.pill(
            fill: InviteEarnTheme.midGreen.withValues(alpha: 0.92),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: InviteEarnTheme.goldLight),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: InviteEarnTheme.cream,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BonusTile extends StatelessWidget {
  const _BonusTile({
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: InviteEarnTheme.goldBorderCard(radius: 14),
      child: Column(
        children: [
          Icon(icon, color: InviteEarnTheme.goldLight, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: InviteEarnTheme.goldLight,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? InviteEarnTheme.goldButton : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? const Color(0xFF3B2500) : InviteEarnTheme.cream,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteCtaButton extends StatelessWidget {
  const _InviteCtaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 8,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: InviteEarnTheme.goldButton,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: InviteEarnTheme.goldLight, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: InviteEarnTheme.gold.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.user_add, color: Color(0xFF3B2500)),
              SizedBox(width: 8),
              Text(
                'Invite Friends',
                style: TextStyle(
                  color: Color(0xFF3B2500),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
