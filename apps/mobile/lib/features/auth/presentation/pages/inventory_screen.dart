import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';
import 'package:sk_live/core/providers/shop_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/inventory_provider.dart';
import 'package:sk_live/core/widgets/dynamic_chat_bubble.dart';
import 'package:sk_live/core/widgets/stretch_chat_bubble.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final String userId;
  final String initialTab;

  const InventoryScreen({
    super.key,
    required this.userId,
    this.initialTab = 'frames',
  });

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab == 'cars') initialIndex = 1;
    if (widget.initialTab == 'entrance') initialIndex = 2;
    if (widget.initialTab == 'medals') initialIndex = 3;
    if (widget.initialTab == 'others') initialIndex = 4;

    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.l10n.inventory_title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white54,
          dividerColor: Colors.white10,
          tabs: [
            Tab(text: context.l10n.inventory_frames),
            Tab(text: context.l10n.inventory_cars),
            Tab(text: context.l10n.inventory_entrance),
            Tab(text: context.l10n.inventory_medals),
            const Tab(text: 'Others'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (isMe) _buildMedalHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInventoryList('frame', isMe),
                _buildInventoryList('car', isMe),
                _buildInventoryList('entrance show', isMe),
                _buildMedalsTab(isMe),
                _buildInventoryList('other', isMe),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedalHeader() {
    final userProfile = ref.watch(userProfileProvider).value;
    if (userProfile == null) return const SizedBox();

    final wealth = (userProfile['wealth_value'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade900.withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.medal, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Gifting Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${NumberFormat.compact().format(wealth)} coins spent',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedalsTab(bool isMe) {
    final medalsAsync = ref.watch(medalItemsProvider);
    final myInventoryAsync = ref.watch(
      userFullInventoryProvider(widget.userId),
    );
    final userProfile = ref.watch(userProfileProvider).value;

    return medalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => asyncErrorWidget(e),
      data: (allMedals) {
        return myInventoryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox(),
          data: (myItems) {
            final myItemIds = myItems.map((e) => e['item_id']).toList();
            final wealth = (userProfile?['wealth_value'] as num?)?.toInt() ?? 0;
            final charm = (userProfile?['charm_value'] as num?)?.toInt() ?? 0;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allMedals.length,
              itemBuilder: (context, index) {
                final medal = allMedals[index];
                final isOwned = myItemIds.contains(medal.id);

                int current = 0;
                int target = 0;
                String unit = 'coins';

                if (medal.requiredWealthValue > 0) {
                  current = wealth;
                  target = medal.requiredWealthValue;
                } else if (medal.requiredCharmValue > 0) {
                  current = charm;
                  target = medal.requiredCharmValue;
                }

                double progress = (target > 0)
                    ? (current / target).clamp(0.0, 1.0)
                    : 1.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isOwned
                          ? Colors.amber.withValues(alpha: 0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: isOwned ? 1.0 : 0.4,
                        child: CachedNetworkImage(
                          imageUrl: medal.imageUrl ?? '',
                          height: 60,
                          width: 60,
                          errorWidget: (_, __, _) => const Icon(
                            Iconsax.medal,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medal.name,
                              style: TextStyle(
                                color: isOwned ? Colors.amber : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (!isOwned && target > 0) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white10,
                                  color: Colors.amber,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${NumberFormat.compact().format(current)} / ${NumberFormat.compact().format(target)} $unit',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ] else if (isOwned) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Unlocked',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isOwned)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInventoryList(String category, bool isMe) {
    final inventoryAsync = ref.watch(userFullInventoryProvider(widget.userId));

    return inventoryAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) =>
          asyncErrorWidget(e, style: const TextStyle(color: Colors.white54)),
      data: (items) {
        final filtered = items.where((item) {
          final catName =
              (item['shop_items']?['shop_categories']?['name'] ?? '')
                  .toString()
                  .toLowerCase();
          if (category == 'frame') return catName == 'profile photo frame';
          if (category == 'car') return catName == 'car';
          if (category == 'entrance show') {
            return catName == 'entrance show';
          }
          if (category == 'other') {
            return catName != 'profile photo frame' &&
                catName != 'car' &&
                catName != 'entrance show';
          }
          return false;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.box_copy,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.inventory_empty,
                  style: const TextStyle(color: Colors.white24),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            final shopItem = item['shop_items'];
            final catName = (shopItem?['shop_categories']?['name'] ?? '')
                .toString();
            final expiresAt = item['expires_at'] != null
                ? DateTime.parse(item['expires_at'])
                : null;
            final isEquipped = item['is_equipped'] ?? false;

            return _buildInventoryCard(
              shopItem,
              expiresAt,
              isEquipped,
              item['id'],
              category,
              isMe,
              catName,
            );
          },
        );
      },
    );
  }

  bool _isProcessing = false;

  Future<void> _equipItem(
    String inventoryId,
    String realCategoryName,
    bool currentlyEquipped,
  ) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (currentlyEquipped) {
        await supabase
            .from('user_inventory')
            .update({'is_equipped': false})
            .eq('id', inventoryId);
      } else {
        final cat = realCategoryName.toLowerCase();
        final exclusiveSlot =
            !cat.contains('title') &&
            !cat.contains('medal') &&
            !cat.contains('badge') &&
            !cat.contains('nameplate');

        if (exclusiveSlot) {
          final myInventory = await supabase
              .from('user_inventory')
              .select('id, shop_items(shop_categories(name))')
              .eq('user_id', widget.userId);

          final toUnequip = (myInventory as List)
              .where((item) {
                final catName =
                    item['shop_items']?['shop_categories']?['name']
                        ?.toString()
                        .toLowerCase() ??
                    '';
                return catName == cat;
              })
              .map((e) => e['id'] as String)
              .toList();

          if (toUnequip.isNotEmpty) {
            await supabase
                .from('user_inventory')
                .update({'is_equipped': false})
                .inFilter('id', toUnequip);
          }
        }

        await supabase
            .from('user_inventory')
            .update({'is_equipped': true})
            .eq('id', inventoryId);
      }

      if (mounted) {
        await refreshUserInventoryCaches(ref, widget.userId);
        ref.invalidate(publicUserProfileProvider(widget.userId));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyEquipped
                  ? 'Un-equipped successfully'
                  : context.l10n.inventory_equippedOk,
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildInventoryCard(
    Map<String, dynamic> item,
    DateTime? expiresAt,
    bool isEquipped,
    String inventoryId,
    String category,
    bool isMe,
    String realCategoryName,
  ) {
    String expiryText = 'Permanent';
    bool isExpired = false;
    if (expiresAt != null) {
      final diff = expiresAt.difference(DateTime.now());
      if (diff.isNegative) {
        expiryText = 'Expired';
        isExpired = true;
      } else if (diff.inDays > 0) {
        expiryText = 'Expires in: ${diff.inDays}d';
      } else {
        expiryText = 'Expires in: ${diff.inHours}h';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEquipped
              ? AppColors.accent
              : Colors.white.withValues(alpha: 0.05),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: realCategoryName.toLowerCase().contains('bubble')
                      ? Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: DynamicChatBubble(
                              userId: widget.userId,
                              username: 'Preview',
                              content: 'Hello World! ✨',
                              iconUrl:
                                  isNineSliceChatBubble(
                                    name: item['name']?.toString(),
                                    imageUrl: item['image_url']?.toString(),
                                  )
                                  ? null
                                  : item['image_url'],
                              frameUrl:
                                  isNineSliceChatBubble(
                                    name: item['name']?.toString(),
                                    imageUrl: item['image_url']?.toString(),
                                  )
                                  ? item['image_url']?.toString()
                                  : null,
                              frameSvgaUrl: item['svga_url']?.toString(),
                              bgColor: _getBubbleColor(
                                item['name'],
                                isBg: true,
                              ),
                              borderColor: _getBubbleColor(
                                item['name'],
                                isBg: false,
                              ),
                            ),
                          ),
                        )
                      : (item['svga_url'] != null &&
                                item['svga_url'].toString().isNotEmpty
                            ? SVGAPlayerMuted(resUrl: item['svga_url'])
                            : (item['image_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: item['image_url'],
                                      fit: BoxFit.contain,
                                    )
                                  : const Icon(
                                      Icons.image,
                                      color: Colors.white24,
                                      size: 40,
                                    ))),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  expiryText,
                  style: TextStyle(
                    color: isExpired ? Colors.redAccent : Colors.white54,
                    fontSize: 11,
                  ),
                ),
                if (isMe && !isExpired) ...[
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _equipItem(
                            inventoryId,
                            realCategoryName,
                            isEquipped,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEquipped
                          ? Colors.grey
                          : AppColors.accent,
                      foregroundColor: isEquipped ? Colors.white : Colors.black,
                      minimumSize: const Size(double.infinity, 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 15,
                            width: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            isEquipped ? 'Equipped' : 'Use',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
          if (isEquipped)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Equipped',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getBubbleColor(String name, {bool isBg = true}) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('purple')) {
      return isBg
          ? const Color(0xFF4A148C).withValues(alpha: 0.5)
          : Colors.purpleAccent;
    } else if (lowerName.contains('teal')) {
      return isBg
          ? const Color(0xFF004D40).withValues(alpha: 0.5)
          : Colors.tealAccent;
    } else if (lowerName.contains('orange') || lowerName.contains('fire')) {
      return isBg
          ? const Color(0xFFBF360C).withValues(alpha: 0.5)
          : Colors.orangeAccent;
    } else if (lowerName.contains('indigo')) {
      return isBg
          ? const Color(0xFF1A237E).withValues(alpha: 0.5)
          : Colors.indigoAccent;
    }
    return isBg
        ? const Color(0xFF4A148C).withValues(alpha: 0.5)
        : Colors.purpleAccent;
  }
}

final medalItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  final supabase = Supabase.instance.client;
  final res = await supabase
      .from('shop_items')
      .select()
      .eq('source_type', 'medal')
      .eq('is_active', true)
      .order('required_wealth_value', ascending: true);

  return (res as List).map((e) => ShopItem.fromMap(e)).toList();
});
