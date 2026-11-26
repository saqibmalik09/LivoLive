import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/wallet_coins_provider.dart';
import 'package:sk_live/core/util/svga_cache.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import 'package:sk_live/core/providers/shop_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/services/task_tracker_service.dart';
import 'package:sk_live/core/util/lucky_gift_ui.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/providers/notification_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/paged_gift_grid.dart';
import 'package:sk_live/features/home/presentation/widgets/room_gift_sender.dart';
import 'package:uuid/uuid.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

typedef GiftSentAnimationCallback =
    void Function({
      required String animationBatchId,
      required String senderId,
      required List<String> targetIds,
      required String giftIcon,
      required int quantity,
      required bool isFullScreen,
      required String svgaUrl,
      bool playFullScreenSvga,
      int priceCoins,
      String? giftName,
    });

typedef GiftBroadcastCallback = void Function(Map<String, dynamic> payload);

class RoomGiftSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;
  final List<Map<String, dynamic>> seats;
  final List<Map<String, dynamic>> audience;
  final GiftSentAnimationCallback? onGiftSent;
  final GiftBroadcastCallback? onGiftBroadcast;
  final void Function(RepeatGiftSession session)? onRepeatGiftReady;
  final Set<String> initialSelectedUserIds;
  final bool initialIsAllSelected;
  final void Function(Set<String> userIds, bool isAllSelected)?
  onTargetSelectionChanged;

  const RoomGiftSheet({
    super.key,
    required this.room,
    required this.seats,
    required this.audience,
    this.onGiftSent,
    this.onGiftBroadcast,
    this.onRepeatGiftReady,
    this.initialSelectedUserIds = const {},
    this.initialIsAllSelected = false,
    this.onTargetSelectionChanged,
  });

  @override
  ConsumerState<RoomGiftSheet> createState() => _RoomGiftSheetState();
}

class _RoomGiftSheetState extends ConsumerState<RoomGiftSheet>
    with TickerProviderStateMixin {
  String? _selectedCategoryId;
  final Set<String> _selectedUserIds = {};
  Map<String, dynamic>? _selectedGift;
  int _selectedQuantity = 1;
  bool _isSending = false;

  final List<int> _quantities = [1, 10, 66, 88, 99, 188, 520, 1314];

  @override
  void initState() {
    super.initState();
    _selectedUserIds.addAll(
      widget.initialSelectedUserIds
          .map((id) => id.toString().trim())
          .where((id) => id.isNotEmpty),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      clearStaleWalletOverrideForGiftSheet(
        ref,
        ref.read(userProfileProvider).value,
      );
      if (widget.initialIsAllSelected) {
        _selectAllMembers();
      } else {
        _syncTargetWithSeatedMembers();
        _ensureDefaultTargetSelected();
      }
    });
  }

  @override
  void dispose() {
    // Never leave the global optimistic wallet stuck if this sheet dies mid-send.
    _isSending = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(RoomGiftSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seats != widget.seats) {
      _syncTargetWithSeatedMembers();
    }
  }

  bool get _isAllSelected {
    final members = _getAllMembers();
    if (members.isEmpty) return false;
    return members.every((m) => _selectedUserIds.contains(m['id']?.toString()));
  }

  void _notifyTargetSelection() {
    widget.onTargetSelectionChanged?.call(
      Set<String>.from(_selectedUserIds),
      _isAllSelected,
    );
  }

  void _selectAllMembers() {
    final ids = _getAllMembers()
        .map((m) => m['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    setState(() {
      _selectedUserIds
        ..clear()
        ..addAll(ids);
    });
    _notifyTargetSelection();
  }

  void _toggleUser(String userId) {
    if (userId.isEmpty) return;
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
    _notifyTargetSelection();
  }

  void _syncTargetWithSeatedMembers() {
    final seatedIds = _getAllMembers()
        .map((m) => m['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final before = _selectedUserIds.length;
    _selectedUserIds.removeWhere((id) => !seatedIds.contains(id));
    if (_selectedUserIds.length != before && mounted) {
      setState(() {});
      _notifyTargetSelection();
    }
  }

  /// Send stays grey when nobody is selected — pick the first seat/audience
  /// member so a normal open is always one tap away from sending.
  void _ensureDefaultTargetSelected() {
    if (_selectedUserIds.isNotEmpty) return;
    final members = _getAllMembers();
    if (members.isEmpty) return;
    final firstId = members.first['id']?.toString().trim() ?? '';
    if (firstId.isEmpty) return;
    setState(() => _selectedUserIds.add(firstId));
    _notifyTargetSelection();
  }

  List<Map<String, dynamic>> _getAllMembers() {
    final Map<String, Map<String, dynamic>> uniqueMembers = {};

    void addUser(dynamic raw) {
      if (raw is! Map) return;
      final user = Map<String, dynamic>.from(raw);
      final id = user['id']?.toString().trim() ?? '';
      if (id.isEmpty) return;
      user['id'] = id;
      uniqueMembers[id] = user;
    }

    for (final seat in widget.seats) {
      addUser(seat['user']);
    }
    for (final person in widget.audience) {
      addUser(person);
      addUser(person['user']);
    }

    return uniqueMembers.values.toList();
  }

  void _toast(String message, {Color color = Colors.redAccent}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep override in sync when the profile stream catches up — never write
    // providers during build (that was locking the Send button after a send).
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userProfileProvider, (
      _,
      next,
    ) {
      syncWalletCoinsOverrideFromProfile(ref, next.valueOrNull);
    });
    final catalogAsync = ref.watch(giftCatalogProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    ref.watch(walletCoinsOverrideProvider);
    final coins = resolveWalletCoins(ref, userProfile);
    final allMembers = _getAllMembers();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          _buildMemberSelection(allMembers),
          const Divider(color: Colors.white10, height: 1),
          catalogAsync.when(
            data: (catalog) {
              final filteredCategories = catalog.categories;

              if (_selectedCategoryId == null &&
                  filteredCategories.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _selectedCategoryId != null) return;
                  setState(
                    () => _selectedCategoryId = filteredCategories[0].id,
                  );
                });
              }
              return SizedBox(
                height: 30,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredCategories.length,
                  itemBuilder: (context, index) {
                    final cat = filteredCategories[index];
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (cat.name.toLowerCase() == 'lucky') ...[
                              const Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              cat.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.amber
                                    : Colors.white38,
                                fontSize: 13,
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
          catalogAsync.when(
            data: (catalog) => _buildGiftPager(catalog),
            loading: () => _buildGiftAreaSlot(
              const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
            error: (e, _) => _buildGiftAreaSlot(
              Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.white24),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          _buildFooter(coins, allMembers),
        ],
      ),
    );
  }

  Widget _buildGiftAreaSlot(Widget child) {
    final height = PagedGiftGrid.sheetGiftAreaHeight(
      MediaQuery.sizeOf(context).width,
    );
    return SizedBox(height: height, width: double.infinity, child: child);
  }

  Widget _buildGiftPager(GiftCatalog catalog) {
    final categories = catalog.categories;
    if (categories.isEmpty) {
      return _buildGiftAreaSlot(
        Center(
          child: Text(
            context.l10n.chat_noGiftCategories,
            style: const TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    // One catalog fetch already holds every category. The old path watched a
    // separate FutureProvider per tab and kept the spinner up until the last
    // one finished — that is why the grid stayed empty for so long.
    final giftsByCategory = catalog.giftsByCategory;
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
      onGiftSelected: (gift) {
        setState(
          () => _selectedGift = {
            'id': gift.id,
            'name': gift.name,
            'price_coins': gift.priceCoins,
            'icon_url': gift.imageUrl,
            'svga_url': gift.svgaUrl,
            'is_full_screen': gift.isFullScreen,
          },
        );
        // Every gift with an animation plays it on send (full screen, or in
        // the centre before the flight), so warm it while the user picks.
        final svga = gift.svgaUrl?.trim() ?? '';
        if (svga.isNotEmpty) {
          unawaited(SvgaCache.preload([svga]));
        }
      },
    );
  }

  Widget _buildMemberSelection(List<Map<String, dynamic>> members) {
    final allSelected = _isAllSelected;
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: members.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _selectAllMembers,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: allSelected ? Colors.amber : Colors.white10,
                        border: Border.all(
                          color: allSelected
                              ? Colors.amber
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'ALL',
                          style: TextStyle(
                            color: allSelected ? Colors.black : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'All',
                      style: TextStyle(color: Colors.white60, fontSize: 9),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = members[index - 1];
          final userId = user['id']?.toString() ?? '';
          final isSelected = _selectedUserIds.contains(userId);
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          final isMe = user['id'] == currentUserId;
          final displayName = isMe ? 'You' : (user['username'] ?? 'User');

          return GestureDetector(
            onTap: () => _toggleUser(userId),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: user['avatar_url'] != null
                          ? AppNetworkImage(
                              imageUrl: user['avatar_url'],
                              fit: BoxFit.cover,
                              transformWidth: 96,
                              transformHeight: 96,
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white24,
                              size: 18,
                            ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 44,
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: isSelected ? Colors.amber : Colors.white60,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(int coins, List<Map<String, dynamic>> members) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
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
          const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
          const Spacer(),
          _buildQuantitySelector(),
          const SizedBox(width: 12),
          ElevatedButton(
            // Always tappable — show why send failed instead of a dead grey button.
            onPressed: _isSending ? null : () => _handleSendGift(members),
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

  void _handleSendGift(List<Map<String, dynamic>> allMembers) async {
    debugPrint(
      '[GIFT_SEND] tap sending=$_isSending '
      'gift=${_selectedGift?['id']} '
      'targets=${_selectedUserIds.length} '
      'qty=$_selectedQuantity',
    );
    if (_isSending) return;
    if (_selectedGift == null) {
      _toast('Select a gift first');
      return;
    }

    if (_selectedUserIds.isEmpty) {
      _ensureDefaultTargetSelected();
    }

    final targets = _selectedUserIds
        .map((id) => id.toString().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    if (targets.isEmpty) {
      _toast('Select who to send the gift to');
      return;
    }

    final unitPrice =
        (_selectedGift!['price_coins'] as num?)?.toInt() ?? 0;
    if (unitPrice <= 0) {
      debugPrint(
        '[GIFT_SEND] bad price_coins=${_selectedGift!['price_coins']}',
      );
      _toast('Gift price unavailable — try another gift');
      return;
    }

    final totalCost = unitPrice * _selectedQuantity * targets.length;

    final userProfile = ref.read(userProfileProvider).value;
    final currentCoins = resolveWalletCoins(ref, userProfile);
    debugPrint(
      '[GIFT_SEND] coins=$currentCoins cost=$totalCost '
      'override=${ref.read(walletCoinsOverrideProvider)} '
      'profileCoins=${userProfile?['coins']}',
    );

    if (currentCoins < totalCost) {
      _toast(context.l10n.room_insufficientCoins);
      return;
    }

    // Cut balance instantly (combo + normal) — never wait on gateway/RPC.
    applyOptimisticCoinSpend(ref, totalCost);
    if (mounted) setState(() => _isSending = true);

    try {
      final supabase = Supabase.instance.client;
      final myUser = ref.read(userProfileProvider).value;
      if (myUser == null || myUser['id'] == null) {
        refundOptimisticCoinSpend(ref, totalCost);
        _toast('Profile still loading — try again');
        return;
      }

      bool anySuccess = false;
      int totalSpentSuccess = 0;
      final giftPrice = unitPrice * _selectedQuantity;
      final animationBatchId = const Uuid().v4();
      final giftIcon = _selectedGift!['icon_url']?.toString() ?? '';
      final svgaUrl = _selectedGift!['svga_url']?.toString() ?? '';
      final isFullScreen = _selectedGift!['is_full_screen'] == true;
      final onRepeatGiftReady = widget.onRepeatGiftReady;

      String? selectedCategoryName;
      final cats = ref.read(giftCategoriesProvider).valueOrNull;
      if (cats != null && _selectedCategoryId != null) {
        for (final c in cats) {
          if (c.id == _selectedCategoryId) {
            selectedCategoryName = c.name;
            break;
          }
        }
      }
      final isLuckyGift = isLuckyCategoryName(selectedCategoryName);
      final isLuckyProGift = isLuckyProCategoryName(selectedCategoryName);
      // All categories settle on the gateway now, one socket call instead of a
      // phone-side RPC plus a second broadcast call. sendRoomGiftsViaGateway
      // falls back to the RPC path by itself when the socket is down or an
      // older gateway rejects the category, so this is safe against mixed
      // versions.
      final useGatewaySettle = AppConstants.useGatewayLuckyEngine;

      if (onRepeatGiftReady != null && targets.isNotEmpty) {
        String targetUsername;
        String? targetAvatarUrl;
        if (_isAllSelected) {
          targetUsername = 'All (${targets.length})';
        } else if (targets.length == 1) {
          final target = allMembers.firstWhere(
            (m) => m['id'].toString() == targets.first,
            orElse: () => {'username': 'User'},
          );
          targetUsername = target['username']?.toString() ?? 'User';
          targetAvatarUrl = target['avatar_url']?.toString();
        } else {
          targetUsername = '${targets.length} users';
        }
        onRepeatGiftReady(
          RepeatGiftSession(
            targetIds: targets.map((id) => id.toString()).toList(),
            sendToAll: _isAllSelected,
            targetUsername: targetUsername,
            targetAvatarUrl: targetAvatarUrl,
            giftId: _selectedGift!['id'].toString(),
            giftName: _selectedGift!['name'].toString(),
            priceCoins: unitPrice,
            giftIcon: giftIcon,
            svgaUrl: svgaUrl,
            isFullScreen: isFullScreen,
            quantity: _selectedQuantity,
            isLuckyGift: isLuckyGift,
            isLuckyProGift: isLuckyProGift,
          ),
        );
      }

      widget.onGiftSent?.call(
        animationBatchId: animationBatchId,
        senderId: myUser['id'].toString(),
        targetIds: targets,
        giftIcon: giftIcon,
        quantity: _selectedQuantity,
        isFullScreen: isFullScreen,
        svgaUrl: svgaUrl,
        playFullScreenSvga: isFullScreen,
        priceCoins: unitPrice,
        giftName: _selectedGift!['name']?.toString(),
      );

      // Unlock Send before network so a slow/hung gateway cannot freeze the UI.
      if (mounted) {
        setState(() => _isSending = false);
        Navigator.pop(context);
      } else {
        _isSending = false;
      }

      final roomId = widget.room['id'].toString();
      final List<RoomGiftSendOutcome> outcomes;
      if (useGatewaySettle) {
        outcomes = await sendRoomGiftsViaGateway(
          supabase: supabase,
          roomId: roomId,
          myUser: myUser,
          targetIds: targets.map((id) => id.toString()).toList(),
          gift: _selectedGift!,
          quantity: _selectedQuantity,
          animationBatchId: animationBatchId,
          allMembers: allMembers,
        );
      } else {
        outcomes = await Future.wait(
          targets.map(
            (targetId) => sendRoomGift(
              supabase: supabase,
              roomId: roomId,
              myUser: myUser,
              targetId: targetId,
              gift: _selectedGift!,
              quantity: _selectedQuantity,
              animationBatchId: animationBatchId,
              allMembers: allMembers,
            ),
          ),
        );
      }

      final successfulTargets = <String>[];
      for (var i = 0; i < outcomes.length; i++) {
        if (outcomes[i].success) successfulTargets.add(targets[i]);
      }

      if (successfulTargets.isNotEmpty) {
        final seatGiftDelta = <String, int>{};
        final messages = <Map<String, dynamic>>[];
        final settledOnGateway = outcomes.any((o) => o.settledOnGateway);
        for (var i = 0; i < outcomes.length; i++) {
          final outcome = outcomes[i];
          if (!outcome.success) continue;
          final delta = outcome.broadcastPayload?['seat_gift_delta'];
          if (delta is Map) {
            delta.forEach((key, value) {
              seatGiftDelta[key.toString()] =
                  (seatGiftDelta[key.toString()] ?? 0) +
                  ((value as num?)?.toInt() ?? 0);
            });
          }
          if (!settledOnGateway && outcome.messageInsert != null) {
            unawaited(persistRoomGiftMessage(supabase, outcome.messageInsert!));
          }
          final msg = outcome.broadcastPayload?['message'];
          if (msg is Map) messages.add(Map<String, dynamic>.from(msg));
        }

        if (outcomes.any((o) => o.success && o.broadcastPayload != null)) {
          Map<String, dynamic>? seatTotals;
          for (final o in outcomes) {
            if (o.seatGiftTotals != null) {
              seatTotals = o.seatGiftTotals;
              break;
            }
          }
          widget.onGiftBroadcast?.call({
            'event_id': '${animationBatchId}_settle',
            'animation_batch_id': animationBatchId,
            'sender_id': myUser['id'].toString(),
            'target_ids': successfulTargets,
            'gift_icon': giftIcon,
            'quantity': _selectedQuantity,
            'is_full_screen': isFullScreen,
            'svga_url': svgaUrl,
            if (useGatewaySettle) 'lucky_engine': 'gateway',
            if (settledOnGateway) 'settled_on_gateway': true,
            if (seatTotals != null) 'seat_gift_totals': seatTotals,
            if (!settledOnGateway || seatTotals == null)
              'seat_gift_delta': seatGiftDelta,
            if (messages.isNotEmpty) 'messages': messages,
            if (messages.isNotEmpty)
              'message': messages.firstWhere((m) {
                final meta = m['metadata'];
                if (meta is! Map) return false;
                return meta['lucky_bonus_won'] == true ||
                    meta['lucky_pro_bonus_won'] == true;
              }, orElse: () => messages.first),
          });
        }
      }

      Map<String, dynamic>? firstLuckyWin;
      for (var i = 0; i < outcomes.length; i++) {
        final outcome = outcomes[i];
        if (!outcome.success) continue;
        anySuccess = true;
        totalSpentSuccess += giftPrice;

        if (outcome.luckyWin) {
          final target = allMembers.firstWhere(
            (m) => m['id'] == targets[i],
            orElse: () => {'username': 'User'},
          );
          firstLuckyWin ??= {'receiver_name': target['username'] ?? 'User'};
        }

        if (mounted &&
            !_isAllSelected &&
            (outcome.isLuckyGift || outcome.isLuckyProGift) &&
            !outcome.luckyWin) {
          final until = outcome.luckyGiftsUntilBonus;
          if (until != null && until > 0) {
            final target = allMembers.firstWhere(
              (m) => m['id'] == targets[i],
              orElse: () => {'username': 'User'},
            );
            showLuckyGiftSnackBar(
              context,
              'Lucky: $until more gift(s) to ${target['username']} for bonus chance',
            );
          }
        }
      }

      if (firstLuckyWin != null) {
        ref.invalidate(systemNotificationsProvider);
      }

      // Refund optimistic spend for targets that failed (keep spent amount).
      final failedCost = totalCost - totalSpentSuccess;
      if (failedCost > 0) {
        refundOptimisticCoinSpend(ref, failedCost);
      }

      if (mounted && _isAllSelected && outcomes.any((o) => o.success)) {
        final sentCount = outcomes.where((o) => o.success).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gift sent to $sentCount people!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (totalSpentSuccess > 0) {
        unawaited(
          TaskTrackerService.trackAction(
            'spend_coins',
            amount: totalSpentSuccess,
          ),
        );
        unawaited(TaskTrackerService.trackAction('newbie_send_gift'));
      }

      if (anySuccess) {
        // Do NOT invalidate userProfile — that flashes loading for the whole
        // wallet UI. Optimistic coins + users realtime stream keep the pill honest.

        if (_selectedGift != null && successfulTargets.isNotEmpty) {
          if (_isAllSelected) {
            onRepeatGiftReady?.call(
              RepeatGiftSession(
                targetIds: successfulTargets
                    .map((id) => id.toString())
                    .toList(),
                sendToAll: true,
                targetUsername: 'All (${successfulTargets.length})',
                giftId: _selectedGift!['id'].toString(),
                giftName: _selectedGift!['name'].toString(),
                priceCoins: unitPrice,
                giftIcon: giftIcon,
                svgaUrl: svgaUrl,
                isFullScreen: isFullScreen,
                quantity: _selectedQuantity,
                isLuckyGift: isLuckyGift,
                isLuckyProGift: isLuckyProGift,
              ),
            );
          } else if (successfulTargets.length == 1) {
            final selectedId = successfulTargets.first.toString();
            final target = allMembers.firstWhere(
              (m) => m['id'].toString() == selectedId,
              orElse: () => {'username': 'User'},
            );
            onRepeatGiftReady?.call(
              RepeatGiftSession(
                targetIds: [selectedId],
                targetUsername: target['username']?.toString() ?? 'User',
                targetAvatarUrl: target['avatar_url']?.toString(),
                giftId: _selectedGift!['id'].toString(),
                giftName: _selectedGift!['name'].toString(),
                priceCoins: unitPrice,
                giftIcon: giftIcon,
                svgaUrl: svgaUrl,
                isFullScreen: isFullScreen,
                quantity: _selectedQuantity,
                isLuckyGift: isLuckyGift,
                isLuckyProGift: isLuckyProGift,
              ),
            );
          } else {
            onRepeatGiftReady?.call(
              RepeatGiftSession(
                targetIds: successfulTargets
                    .map((id) => id.toString())
                    .toList(),
                sendToAll: false,
                targetUsername: '${successfulTargets.length} users',
                giftId: _selectedGift!['id'].toString(),
                giftName: _selectedGift!['name'].toString(),
                priceCoins: unitPrice,
                giftIcon: giftIcon,
                svgaUrl: svgaUrl,
                isFullScreen: isFullScreen,
                quantity: _selectedQuantity,
                isLuckyGift: isLuckyGift,
                isLuckyProGift: isLuckyProGift,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Send Gift Error: $e');
      refundOptimisticCoinSpend(ref, totalCost);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send gift'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isSending = false;
      if (mounted) setState(() {});
    }
  }
}
