import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/buddy_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/features/home/presentation/pages/intimacy_list_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/buddy_invite_dialog.dart';

class BuddyHubScreen extends ConsumerStatefulWidget {
  const BuddyHubScreen({super.key, this.initialTier = BuddyTier.homie});

  final BuddyTier initialTier;

  @override
  ConsumerState<BuddyHubScreen> createState() => _BuddyHubScreenState();
}

class _BuddyHubScreenState extends ConsumerState<BuddyHubScreen> {
  late BuddyTier _tier;

  @override
  void initState() {
    super.initState();
    _tier = widget.initialTier;
  }

  Color get _accent {
    switch (_tier) {
      case BuddyTier.friend:
        return const Color(0xFF4DA3FF);
      case BuddyTier.bestie:
        return const Color(0xFF3DCC6E);
      case BuddyTier.homie:
        return const Color(0xFFFF8A2B);
    }
  }

  List<Color> get _ctaGradient {
    switch (_tier) {
      case BuddyTier.friend:
        return const [Color(0xFF5BB0FF), Color(0xFF2F6BFF)];
      case BuddyTier.bestie:
        return const [Color(0xFF6BE08A), Color(0xFF1FAF55)];
      case BuddyTier.homie:
        return const [Color(0xFFFFD24A), Color(0xFFFF7A1A)];
    }
  }

  String? get _myUserId {
    final fromProfile = ref.read(userProfileProvider).value?['id']?.toString();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return ref.read(authStateProvider).value?.session?.user.id;
  }

  @override
  Widget build(BuildContext context) {
    final myId = _myUserId;
    final boardAsync = myId == null
        ? null
        : ref.watch(intimacyBoardProvider(myId));
    final board = boardAsync?.asData?.value;
    final count = board?.closeFriendsCount ?? 0;
    final limit = board?.closeFriendsLimit ?? 6;
    final tierBuddies = (board?.buddies ?? [])
        .where((b) => (b['tier']?.toString() ?? '') == _tier.dbValue)
        .toList();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _tier.bgAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (myId != null)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    IntimacyListScreen(userId: myId),
                              ),
                            );
                          },
                          child: const Text(
                            'My list',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (tierBuddies.isNotEmpty) ...[
                  SizedBox(
                    height: 86,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: tierBuddies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final b = tierBuddies[index];
                        final avatar = b['avatar_url']?.toString();
                        final name =
                            b['username']?.toString() ??
                            context.l10n.common_user;
                        final intimacy = (b['intimacy'] as num?)?.toInt() ?? 0;
                        return Container(
                          width: 150,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: avatar != null
                                    ? CachedNetworkImageProvider(avatar)
                                    : null,
                                child: avatar == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      NumberFormatter.format(intimacy),
                                      style: TextStyle(
                                        color: _accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTierTabs(
                  selected: _tier,
                  accent: _accent,
                  onSelect: (t) => setState(() => _tier = t),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _ctaGradient),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => showBuddyInviteSheet(
                            context,
                            ref: ref,
                            tier: _tier,
                          ),
                          child: Center(
                            child: Text(
                              '+ ${_tier.label}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: myId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IntimacyListScreen(userId: myId),
                            ),
                          );
                        },
                  child: Text.rich(
                    TextSpan(
                      text: 'Close Friends (',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: '$count/$limit',
                          style: TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(text: ')'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierTabs({
    required BuddyTier selected,
    required Color accent,
    required ValueChanged<BuddyTier> onSelect,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: BuddyTier.values.map((t) {
        final isSelected = t == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => onSelect(t),
            child: Column(
              children: [
                if (isSelected)
                  Icon(Icons.arrow_drop_down, color: accent, size: 22)
                else
                  const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Each tier now carries its own mark, so Friend,
                      // Bestie and Homie are told apart at a glance rather
                      // than by reading three similar words.
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: t.colors,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: t.colors.last.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(t.icon, size: 13, color: Colors.white),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
