import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/providers/shop_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';
import 'package:sk_live/core/widgets/dynamic_chat_bubble.dart';
import 'package:sk_live/core/widgets/stretch_chat_bubble.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/features/home/presentation/widgets/shop_item_preview.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, this.initialCategoryName});

  final String? initialCategoryName;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  String? _selectedCategoryId;
  ShopItem? _selectedItem;
  bool _isProcessing = false;

  void _handlePurchase(ShopItem item) async {
    final userProfile = ref.read(userProfileProvider).value;
    final coins = (userProfile?['coins'] as num?)?.toInt() ?? 0;

    if (coins < item.priceCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.shop_insufficientCoins),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'purchase_shop_item',
        params: {'p_item_id': item.id},
      );

      if (response != null && response['success'] == true) {
        ref.invalidate(userProfileProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Purchased successfully! Wealth Level: ${response['new_wealth_level']}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shop_purchaseFailed),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleSendGlobal(ShopItem item, Map<String, dynamic> targetUser) async {
    final userProfile = ref.read(userProfileProvider).value;
    final coins = (userProfile?['coins'] as num?)?.toInt() ?? 0;

    if (coins < item.priceCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.shop_insufficientCoins),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'send_gift',
        params: {
          'p_sender_id': userProfile!['id'],
          'p_receiver_id': targetUser['id'],
          'p_gift_id': item.id,
          'p_room_id': null,
          'p_quantity': 1,
        },
      );

      if (response != null && response['success'] == true) {
        ref.invalidate(userProfileProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sent ${item.name} to ${targetUser['username']}! Wealth Lvl: ${response['new_wealth_level']}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shop_sendGiftFailed),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showUserSearchSheet(ShopItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserSearchSheet(
        onUserSelected: (user) {
          Navigator.pop(context);
          _handleSendGlobal(item, user);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(shopCategoriesProvider);
    final userProfile = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppColors.shopBackgroundGradient,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(userProfile),
                Expanded(
                  child: Row(
                    children: [
                      _buildSidebar(categoriesAsync),
                      Expanded(child: _buildItemsGrid()),
                    ],
                  ),
                ),
                _buildBottomBar(userProfile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? userProfile) {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            context.l10n.shop_title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              final myId = Supabase.instance.client.auth.currentUser?.id;
              if (myId != null) {
                context.push(AppRouter.inventory, extra: {'userId': myId});
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.backpack_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.shop_mine,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(AsyncValue<List<ShopCategory>> categoriesAsync) {
    return Container(
      width: 100,
      decoration: const BoxDecoration(
        gradient: AppColors.shopSidebarGradient,
        border: Border(right: BorderSide(color: Colors.white24)),
      ),
      child: categoriesAsync.when(
        data: (categories) {
          if (_selectedCategoryId == null && categories.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              String? targetId;
              final initial = widget.initialCategoryName?.toLowerCase();
              if (initial != null && initial.isNotEmpty) {
                for (final cat in categories) {
                  if (cat.name.toLowerCase() == initial) {
                    targetId = cat.id;
                    break;
                  }
                }
              }
              setState(
                () => _selectedCategoryId = targetId ?? categories[0].id,
              );
            });
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategoryId == cat.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategoryId = cat.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.transparent,
                    border: isSelected
                        ? const Border(
                            left: BorderSide(color: Colors.white, width: 3),
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _getCategoryIcon(cat.name),
                        color: isSelected ? Colors.white : Colors.white70,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (e, _) => const Icon(Icons.error, color: Colors.white24),
      ),
    );
  }

  Widget _buildItemsGrid() {
    if (_selectedCategoryId == null) return const SizedBox();

    final itemsAsync = ref.watch(shopItemsProvider(_selectedCategoryId!));

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No items found',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildShopItemCard(item);
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) =>
          asyncErrorWidget(e, style: const TextStyle(color: Colors.white38)),
    );
  }

  Widget _buildShopItemCard(ShopItem item) {
    final isSelected = _selectedItem?.id == item.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedItem = item),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? AppColors.shopCardGradient
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.gold.withValues(alpha: 0.35),
                    AppColors.primaryDark.withValues(alpha: 0.55),
                  ],
                ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.durationDays} day',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ),
            if (item.categoryName?.toLowerCase() != 'bubble' &&
                (!item.isForSale ||
                    item.requiredVipLevel > 0 ||
                    item.sourceType == 'medal'))
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.requiredVipLevel > 0
                        ? Colors.deepPurple
                        : (item.sourceType == 'medal'
                              ? Colors.blueAccent
                              : Colors.redAccent),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                    ),
                  ),
                  child: Text(
                    item.requiredVipLevel > 0
                        ? 'VIP Lv.${item.requiredVipLevel}'
                        : (item.sourceType == 'medal'
                              ? 'MEDAL'
                              : 'NOT FOR SALE'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showPreview(item),
                child: Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: item.categoryName?.toLowerCase() == 'bubble'
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DynamicChatBubble(
                              username: 'Preview',
                              content: 'Nice Bubble!',
                              iconUrl:
                                  isNineSliceChatBubble(
                                    name: item.name,
                                    imageUrl: item.imageUrl,
                                  )
                                  ? null
                                  : item.imageUrl,
                              frameUrl:
                                  isNineSliceChatBubble(
                                    name: item.name,
                                    imageUrl: item.imageUrl,
                                  )
                                  ? item.imageUrl
                                  : null,
                              frameSvgaUrl: item.svgaUrl,
                              bgColor: _getBubbleColor(item.name, isBg: true),
                              borderColor: _getBubbleColor(
                                item.name,
                                isBg: false,
                              ),
                              iconSize: 18,
                            ),
                          )
                        : (item.svgaUrl != null && item.svgaUrl!.isNotEmpty)
                        ? SVGAPlayerMuted(resUrl: item.svgaUrl!)
                        : (item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? AppNetworkImage(
                                  imageUrl: item.imageUrl!,
                                  fit: BoxFit.contain,
                                  transformWidth: 320,
                                  transformHeight: 320,
                                  transformResize: 'contain',
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white24,
                                        size: 40,
                                      ),
                                )
                              : const Icon(
                                  Icons.image,
                                  color: Colors.white24,
                                  size: 50,
                                )),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars, color: AppColors.gold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${item.priceCoins}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientActionButton({
    required String label,
    required LinearGradient gradient,
    required bool enabled,
    required VoidCallback onPressed,
    required double minWidth,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !_isProcessing ? onPressed : null,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled ? gradient : null,
              color: enabled ? null : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: gradient.colors.last.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: BoxConstraints(minWidth: minWidth, minHeight: 40),
              alignment: Alignment.center,
              child: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic>? userProfile) {
    final coins = (userProfile?['coins'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      decoration: BoxDecoration(
        color: AppColors.shopBarBackground,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: AppColors.gold, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              NumberFormatter.format(coins),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
          const Spacer(),
          _gradientActionButton(
            label: context.l10n.shop_send,
            gradient: AppColors.sendButtonGradient,
            enabled:
                _selectedItem != null &&
                _selectedItem!.isForSale &&
                !_isProcessing,
            onPressed: () => _showUserSearchSheet(_selectedItem!),
            minWidth: 60,
          ),
          const SizedBox(width: 8),
          _gradientActionButton(
            label: _selectedItem == null
                ? context.l10n.shop_purchase
                : (!_selectedItem!.isForSale
                      ? (_selectedItem!.sourceType == 'vip'
                            ? context.l10n.shop_vipLevelBadge(
                                _selectedItem!.requiredVipLevel,
                              )
                            : (_selectedItem!.sourceType == 'medal'
                                  ? context.l10n.shop_medalOnly
                                  : context.l10n.shop_locked))
                      : context.l10n.shop_purchase),
            gradient: AppColors.purchaseButtonGradient,
            enabled:
                _selectedItem != null &&
                _selectedItem!.isForSale &&
                !_isProcessing,
            onPressed: () => _handlePurchase(_selectedItem!),
            minWidth: 80,
          ),
        ],
      ),
    );
  }

  void _showPreview(ShopItem item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.9),
      pageBuilder: (context, anim1, anim2) {
        return ShopItemPreview(item: item);
      },
    );
  }

  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'car':
        return Iconsax.car_copy;
      case 'profile photo frame':
        return Iconsax.frame_1;
      case 'special id':
        return Iconsax.tag_2;
      case 'ring':
        return Iconsax.medal_star;
      case 'profile card background':
        return Iconsax.gallery;
      case 'entrance show':
        return Iconsax.flash_1;
      case 'bubble':
        return Iconsax.message_text;
      default:
        return Iconsax.shop_add;
    }
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

class _UserSearchSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onUserSelected;
  const _UserSearchSheet({required this.onUserSelected});

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    final trimmed = query.trim();
    if (!isUserSearchQueryReady(trimmed)) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      const select = 'id, username, avatar_url, wealth_level, short_id';

      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(trimmed);

      late final List response;
      if (isUuid) {
        response = await supabase
            .from('users')
            .select(select)
            .eq('id', trimmed)
            .limit(5);
      } else if (isNumericUidQuery(trimmed)) {
        response = await supabase
            .from('users')
            .select(select)
            .eq('short_id', int.parse(trimmed))
            .limit(5);
      } else {
        response = await supabase
            .from('users')
            .select(select)
            .ilike('username', '%$trimmed%')
            .limit(10);
      }

      setState(
        () => _searchResults = List<Map<String, dynamic>>.from(response),
      );
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Send Gift To',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by username or ID...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(
                  Iconsax.search_status,
                  color: AppColors.gold,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _searchResults.isEmpty
                ? const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: Colors.white24),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['avatar_url'] != null
                                ? CachedNetworkImageProvider(user['avatar_url'])
                                : null,
                            child: user['avatar_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            user['username'] ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Wealth Level: ${user['wealth_level']}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.send,
                            color: AppColors.gold,
                          ),
                          onTap: () => widget.onUserSelected(user),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
