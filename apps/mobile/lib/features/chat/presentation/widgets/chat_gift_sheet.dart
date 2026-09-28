import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:sk_live/core/providers/shop_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/services/task_tracker_service.dart';
import 'package:sk_live/core/util/lucky_gift_ui.dart';
import 'package:sk_live/core/providers/notification_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/paged_gift_grid.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class ChatGiftSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final String targetUserId;
  final String targetUsername;
  final String? targetAvatar;
  final Map<String, dynamic>? replyToMetadata;

  const ChatGiftSheet({
    super.key,
    required this.conversationId,
    required this.targetUserId,
    required this.targetUsername,
    this.targetAvatar,
    this.replyToMetadata,
  });

  @override
  ConsumerState<ChatGiftSheet> createState() => _ChatGiftSheetState();
}

class _ChatGiftSheetState extends ConsumerState<ChatGiftSheet>
    with TickerProviderStateMixin {
  String? _selectedCategoryId;
  Map<String, dynamic>? _selectedGift;
  int _selectedQuantity = 1;
  bool _isSending = false;

  final List<int> _quantities = [1, 10, 66, 88, 99, 188, 520, 1314];

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(giftCategoriesProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final coins = (userProfile?['coins'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          _buildTargetUserInfo(),
          const Divider(color: Colors.white10, height: 1),
          categoriesAsync.when(
            data: (categories) {
              if (_selectedCategoryId == null && categories.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => _selectedCategoryId = categories[0].id);
                });
              }
              return SizedBox(
                height: 30,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategoryId == cat.id;
                    return GestureDetector(
                      onTap: () {
                        if (_selectedCategoryId != cat.id) {
                          setState(() => _selectedCategoryId = cat.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected
                                  ? Colors.amber
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            color: isSelected ? Colors.amber : Colors.white38,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox(height: 30),
            error: (e, _) => const SizedBox(height: 30),
          ),
          if (ref.watch(hasActiveEventGiftMarkersProvider))
            EventGiftMarkerLegend(
              kinds: ref.watch(activeEventGiftMarkerKindsProvider),
            ),
          categoriesAsync.when(
            data: (categories) => _buildGiftPager(categories),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: Colors.amber),
            ),
            error: (e, _) => asyncErrorWidget(
              e,
              style: const TextStyle(color: Colors.white24),
            ),
          ),
          _buildFooter(coins),
        ],
      ),
    );
  }

  Widget _buildGiftPager(List<ShopCategory> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Text(
          context.l10n.chat_noGiftCategories,
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }

    final giftsByCategory = <String, List<ShopItem>>{};
    for (final cat in categories) {
      final itemsAsync = ref.watch(giftItemsProvider(cat.id));
      if (!itemsAsync.hasValue) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        );
      }
      giftsByCategory[cat.id] = itemsAsync.value!;
    }

    final categoryIds = categories.map((c) => c.id).toList();
    final eventMarkers = ref.watch(activeEventGiftMarkersProvider);

    return PagedGiftGrid(
      categoryIds: categoryIds,
      giftsByCategory: giftsByCategory,
      selectedCategoryId: _selectedCategoryId ?? categoryIds.first,
      onCategoryChanged: (catId) {
        if (_selectedCategoryId != catId) {
          setState(() => _selectedCategoryId = catId);
        }
      },
      selectedGiftId: _selectedGift?['id'] as String?,
      eventMarkers: eventMarkers,
      onGiftSelected: (gift) => setState(
        () => _selectedGift = {
          'id': gift.id,
          'name': gift.name,
          'price_coins': gift.priceCoins,
          'icon_url': gift.imageUrl,
          'svga_url': gift.svgaUrl,
          'is_full_screen': gift.isFullScreen,
        },
      ),
    );
  }

  Widget _buildTargetUserInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: widget.targetAvatar != null
                ? CachedNetworkImageProvider(widget.targetAvatar!)
                : null,
            child: widget.targetAvatar == null
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sending to ${widget.targetUsername}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Text(
                'Gifts will be sent in chat',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int coins) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.coin, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Text(
            NumberFormatter.format(coins),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          _buildQuantitySelector(),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (_selectedGift != null && !_isSending)
                ? _handleSendGift
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              disabledBackgroundColor: Colors.white10,
            ),
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    context.l10n.chat_send,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return PopupMenuButton<int>(
      onSelected: (val) => setState(() => _selectedQuantity = val),
      offset: const Offset(0, -250),
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              '$_selectedQuantity',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_up, color: Colors.white60),
          ],
        ),
      ),
      itemBuilder: (context) => _quantities
          .map(
            (q) => PopupMenuItem(
              value: q,
              child: Text('$q', style: const TextStyle(color: Colors.white)),
            ),
          )
          .toList(),
    );
  }

  Future<void> _handleSendGift() async {
    if (_selectedGift == null) return;

    final totalCost =
        (_selectedGift!['price_coins'] as int) * _selectedQuantity;

    final userProfile = ref.read(userProfileProvider).value;
    final currentCoins = (userProfile?['coins'] as num?)?.toInt() ?? 0;

    if (currentCoins < totalCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chat_insufficientBalance),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final supabase = Supabase.instance.client;
      final myUser = ref.read(userProfileProvider).value;
      if (myUser == null) return;

      final response = await supabase.rpc(
        'send_gift',
        params: {
          'p_sender_id': myUser['id'],
          'p_receiver_id': widget.targetUserId,
          'p_gift_id': _selectedGift!['id'],
          'p_room_id': null,
          'p_quantity': _selectedQuantity,
        },
      );

      if (response != null && response['success'] == true) {
        final spentCoins =
            (_selectedGift!['price_coins'] as int) * _selectedQuantity;
        await TaskTrackerService.trackAction('spend_coins', amount: spentCoins);

        final luckyBonusWon = response['lucky_bonus_won'] == true;
        final luckyBonusCoins =
            (response['lucky_bonus_coins'] as num?)?.toInt() ?? 0;
        final isLuckyGift = response['is_lucky_gift'] == true;

        if (luckyBonusWon && mounted) {
          ref.invalidate(systemNotificationsProvider);
          ref.invalidate(userProfileProvider);
          showLuckyGiftBonusFeedback(
            context,
            bonusCoins: luckyBonusCoins,
            giftValue: spentCoins,
          );
        } else if (isLuckyGift && mounted) {
          final until = (response['lucky_gifts_until_bonus'] as num?)?.toInt();
          if (until != null && until > 0) {
            showLuckyGiftSnackBar(
              context,
              'Lucky: $until more gift(s) to same user for bonus chance',
            );
          }
        }

        await ChatService.sendMessage(
          conversationId: widget.conversationId,
          type: 'gift',
          content: luckyBonusWon
              ? 'sent ${_selectedQuantity}x ${_selectedGift!['name']} — You won $luckyBonusCoins lucky bonus!'
              : 'sent ${_selectedQuantity}x ${_selectedGift!['name']}',
          metadata: {
            'gift_id': _selectedGift!['id'],
            'quantity': _selectedQuantity,
            'target_id': widget.targetUserId,
            'gift_name': _selectedGift!['name'],
            'gift_icon': _selectedGift!['icon_url'],
            'svga_url': _selectedGift!['svga_url'],
            'is_full_screen': _selectedGift!['is_full_screen'] ?? false,
            'is_lucky_gift': isLuckyGift,
            'lucky_bonus_won': luckyBonusWon,
            'lucky_bonus_coins': luckyBonusCoins,
            'host_received':
                (response['host_received'] as num?)?.toInt() ??
                (response['host_share'] as num?)?.toInt() ??
                0,
            'host_share':
                (response['host_share'] as num?)?.toInt() ??
                (response['host_received'] as num?)?.toInt() ??
                0,
            ...?widget.replyToMetadata,
          },
        );

        ref.invalidate(userProfileProvider);
        if (mounted) {
          Navigator.pop(context);
          final hostDiamonds =
              (response['host_received'] as num?)?.toInt() ??
              (response['host_share'] as num?)?.toInt() ??
              0;
          final hostCredited =
              response['host_credited'] == true || hostDiamonds > 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hostCredited
                    ? 'Gift sent successfully!'
                    : 'Gift sent — receiver is not in an agency (no gift diamonds).',
              ),
              backgroundColor: hostCredited ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Chat Send Gift Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send gift'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
