import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/cp_nest_provider.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/features/home/presentation/pages/cp_user_search_screen.dart';
import 'package:sk_live/features/home/presentation/pages/cp_ranking_screen.dart';
import 'package:sk_live/features/home/presentation/pages/cp_proposals_screen.dart';
import 'package:go_router/go_router.dart';

class CPNestScreen extends ConsumerWidget {
  const CPNestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(cpNestItemsProvider);
    final coupleAsync = ref.watch(currentCoupleProvider);
    final proposalsAsync = ref.watch(pendingProposalsProvider);
    final configsAsync = ref.watch(cpLevelConfigsProvider);

    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/social/cp_nest_bg.webp',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFC0CB), Colors.white],
                ),
              ),
            ),
          ),

          Container(color: Colors.white.withValues(alpha: 0.1)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.pinkAccent,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.cp_nestTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.pinkAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.help_outline,
                          color: Colors.pinkAccent,
                        ),
                        onPressed: () => context.push('/cp-level'),
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Iconsax.notification_copy,
                              color: Colors.pinkAccent,
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CPProposalsScreen(),
                              ),
                            ),
                          ),
                          proposalsAsync.when(
                            data: (list) => list.isNotEmpty
                                ? Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${list.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (e, _) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Iconsax.ranking,
                          color: Colors.pinkAccent,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CPRankingScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                coupleAsync.when(
                  data: (couple) {
                    if (couple == null) return const SizedBox.shrink();
                    final user1 = couple['user1'];
                    final user2 = couple['user2'];
                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPartnerAvatar(user1['avatar_url']),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(
                                  Icons.favorite,
                                  color: Colors.pinkAccent,
                                  size: 30,
                                ),
                              ),
                              _buildPartnerAvatar(user2['avatar_url']),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user1['username'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                ' ❤️ ',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                user2['username'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          configsAsync.when(
                            data: (configs) {
                              final int currentLevel = couple['cp_level'] ?? 1;
                              final int currentExp = couple['cp_exp'] ?? 0;

                              final currentLevelConfig = configs.firstWhere(
                                (c) => c['level'] == currentLevel,
                                orElse: () => <String, dynamic>{'min_exp': 0},
                              );

                              final nextLevelList = configs
                                  .where((c) => c['level'] == currentLevel + 1)
                                  .toList();
                              final Map<String, dynamic>? nextLevelConfig =
                                  nextLevelList.isNotEmpty
                                  ? nextLevelList.first
                                  : null;

                              final int minExp =
                                  (currentLevelConfig['min_exp'] as num)
                                      .toInt();
                              final int? nextMinExp = nextLevelConfig != null
                                  ? (nextLevelConfig['min_exp'] as num).toInt()
                                  : null;

                              double progress = 0.0;
                              if (nextMinExp != null) {
                                progress =
                                    (currentExp - minExp) /
                                    (nextMinExp - minExp);
                              } else {
                                progress = 1.0;
                              }

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.orange,
                                              Colors.redAccent,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'CP Lv.$currentLevel',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        nextMinExp != null
                                            ? 'EXP: $currentExp / $nextMinExp'
                                            : 'MAX LEVEL',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 200,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.pink.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress.clamp(0.0, 1.0),
                                        backgroundColor: Colors.transparent,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.pinkAccent,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (e, _) => const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _showBreakupDialog(context, ref),
                            icon: const Icon(
                              Icons.heart_broken,
                              color: Colors.grey,
                              size: 18,
                            ),
                            label: const Text(
                              'Break Up',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Build Your Romantic Nest',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: Text(
                    'Purchase exclusive items to decorate your couple space and show your love.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: itemsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    ),
                    error: (e, st) => Center(child: Text('Error: $e')),
                    data: (items) {
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CPUserSearchScreen(item: item),
                              ),
                            ),
                            child: _buildGiftCard(item),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerAvatar(String? url) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.pinkAccent,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 25,
        backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
        child: url == null ? const Icon(Icons.person) : null,
      ),
    );
  }

  void _showBreakupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.cp_breakUpTitle),
        content: const Text(
          'Are you sure you want to end this relationship? Note: Females will be charged a penalty of coins to break up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () async {
              try {
                await CPNestActions.breakupCouple();
                ref.invalidate(currentCoupleProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Relationship ended.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: Text(
              context.l10n.common_confirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCard(CPNestItemModel item) {
    final svga = item.svgaUrl?.trim();
    final img = item.imageUrl?.trim();
    final svgaUrl = (svga != null && svga.isNotEmpty)
        ? svga
        : (img != null && img.toLowerCase().contains('.svga') ? img : null);
    final imageUrl = svgaUrl == null && img != null && img.isNotEmpty
        ? img
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: svgaUrl != null
                  ? RaveSVGAPlayer(
                      resUrl: svgaUrl,
                      fit: BoxFit.contain,
                      repeat: true,
                    )
                  : imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const Icon(Icons.image, color: Colors.grey),
                    )
                  : Icon(
                      _getIconForCategory(item.category),
                      size: 60,
                      color: Colors.pinkAccent.withValues(alpha: 0.8),
                    ),
            ),
          ),

          Text(
            item.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.generating_tokens,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.price}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category?.toLowerCase()) {
      case 'ring':
        return Icons.favorite_border;
      case 'boutique':
        return Icons.auto_awesome;
      case 'card':
        return Icons.card_giftcard;
      case 'frame':
        return Icons.filter_frames;
      default:
        return Icons.card_giftcard;
    }
  }
}
