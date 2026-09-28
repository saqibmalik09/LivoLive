import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/buddy_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/features/home/presentation/pages/buddy_hub_screen.dart';

class IntimacyListScreen extends ConsumerWidget {
  const IntimacyListScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(intimacyBoardProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.intimacy_title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuddyHubScreen()),
              );
            },
            icon: const Icon(Icons.help_outline, color: Colors.black54),
          ),
        ],
      ),
      body: boardAsync.when(
        data: (board) {
          final cards = board.allCards;
          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No intimacy connections yet',
                    style: TextStyle(color: Colors.black45, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BuddyHubScreen(),
                        ),
                      );
                    },
                    child: const Text('Invite a buddy'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _IntimacyCard(
                card: card,
                onTap: () {
                  final id = card['user_id']?.toString();
                  if (id == null || id.isEmpty) return;
                  context.push(AppRouter.userProfile, extra: id);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _IntimacyCard extends StatelessWidget {
  const _IntimacyCard({required this.card, required this.onTap});

  final Map<String, dynamic> card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = (card['tier'] ?? card['kind'] ?? 'friend').toString();
    final colors = _colorsFor(tier);
    final username = card['username']?.toString() ?? 'User';
    final avatar = card['avatar_url']?.toString();
    final days = (card['days'] as num?)?.toInt() ?? 0;
    final intimacy = (card['intimacy'] as num?)?.toInt() ?? 0;
    final badgeLabel = _labelFor(tier);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  backgroundImage: avatar != null
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                color: colors.last,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$days Days',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 14, color: colors.last),
                      const SizedBox(width: 4),
                      Text(
                        NumberFormatter.format(intimacy),
                        style: TextStyle(
                          color: colors.last,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _labelFor(String tier) {
    switch (tier.toLowerCase()) {
      case 'couple':
        return 'Couple';
      case 'bestie':
        return 'Bestie';
      case 'homie':
        return 'Homie';
      default:
        return 'Friend';
    }
  }

  List<Color> _colorsFor(String tier) {
    switch (tier.toLowerCase()) {
      case 'couple':
        return const [Color(0xFFFF6BA8), Color(0xFFE91E63)];
      case 'bestie':
        return const [Color(0xFF6BE08A), Color(0xFF1FAF55)];
      case 'homie':
        return const [Color(0xFFFFC857), Color(0xFFFF7A1A)];
      case 'friend':
      default:
        return const [Color(0xFF6BB6FF), Color(0xFF2F6BFF)];
    }
  }
}
