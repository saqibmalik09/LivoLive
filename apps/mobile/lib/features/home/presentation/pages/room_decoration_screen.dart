import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/room_decoration_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/features/wallet/presentation/pages/wallet_screen.dart';
import 'package:sk_live/core/services/upload_service.dart';
import 'package:sk_live/core/providers/room_info_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/widgets/room_background_media.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';

class RoomDecorationScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? currentDecorationId;
  final String? currentBackgroundUrl;

  const RoomDecorationScreen({
    super.key,
    required this.roomId,
    this.currentDecorationId,
    this.currentBackgroundUrl,
  });

  @override
  ConsumerState<RoomDecorationScreen> createState() =>
      _RoomDecorationScreenState();
}

class _RoomDecorationScreenState extends ConsumerState<RoomDecorationScreen> {
  String? _selectedDecorationId;
  bool _isCustomSelected = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedDecorationId = widget.currentDecorationId;
    _isCustomSelected =
        widget.currentDecorationId == null &&
        widget.currentBackgroundUrl != null &&
        widget.currentBackgroundUrl!.isNotEmpty;
  }

  int _decorationPrice(Map<String, dynamic> decoration) {
    if (decoration['is_premium'] != true) return 0;
    return (decoration['price'] as num?)?.toInt() ?? 0;
  }

  Future<bool> _confirmCharge(String title, int coins) async {
    if (coins <= 0) return true;
    final balance =
        (ref.read(userProfileProvider).value?['coins'] as num?)?.toInt() ?? 0;

    if (balance < coins) {
      if (!mounted) return false;
      final goWallet = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Insufficient coins'),
          content: Text('You need $coins coins. Your balance: $balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Recharge'),
            ),
          ],
        ),
      );
      if (goWallet == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalletScreen()),
        );
      }
      return false;
    }

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(
              'This will deduct $coins coins from your account. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _afterSuccess({int coinsCharged = 0}) async {
    ref.invalidate(userProfileProvider);
    ref.invalidate(roomInfoProvider(widget.roomId));
    if (mounted && coinsCharged > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied! $coinsCharged coins deducted.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room decoration updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _applyCatalog(Map<String, dynamic> decoration) async {
    final id = decoration['id']?.toString();
    if (id == null) return;

    final price = _decorationPrice(decoration);
    if (!await _confirmCharge('Apply decoration', price)) return;

    setState(() => _busy = true);
    try {
      final result = await RoomDecorationActions.applyCatalogDecoration(
        roomId: widget.roomId,
        decorationId: id,
      );

      if (result['success'] == true) {
        setState(() {
          _selectedDecorationId = id;
          _isCustomSelected = false;
        });
        await _afterSuccess(
          coinsCharged: (result['coins_charged'] as num?)?.toInt() ?? 0,
        );
      } else if (mounted) {
        _showError(result['message']?.toString() ?? 'Failed to apply');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadAndApplyCustom() async {
    final customPriceAsync = ref.read(roomCustomBackgroundPriceProvider);
    final customPrice = customPriceAsync.value ?? 500;

    if (!await _confirmCharge('Custom background', customPrice)) return;

    setState(() => _busy = true);
    try {
      final url = await UploadService.instance.pickRoomBackground(context);
      if (url == null) {
        setState(() => _busy = false);
        return;
      }

      final result = await RoomDecorationActions.applyCustomBackground(
        roomId: widget.roomId,
        backgroundUrl: url,
      );

      if (result['success'] == true) {
        setState(() {
          _selectedDecorationId = null;
          _isCustomSelected = true;
        });
        await _afterSuccess(
          coinsCharged: (result['coins_charged'] as num?)?.toInt() ?? 0,
        );
      } else if (mounted) {
        _showError(result['message']?.toString() ?? 'Failed to apply');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildDecorationPreview(Map<String, dynamic> decoration) {
    final svgaUrl = decoration['svga_url']?.toString();
    final imageUrl = decoration['image_url']?.toString() ?? '';

    if (svgaUrl != null && svgaUrl.isNotEmpty) {
      return SVGAPlayerMuted(resUrl: svgaUrl, fit: BoxFit.cover);
    }
    if (MediaUrlUtil.isSvgaUrl(imageUrl)) {
      return SVGAPlayerMuted(resUrl: imageUrl, fit: BoxFit.cover);
    }
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Icon(
          Iconsax.gallery,
          size: 40,
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: Colors.grey[200]),
      errorWidget: (context, url, error) =>
          const Icon(Icons.image_not_supported),
    );
  }

  Widget _buildCustomUploadCard(int customPrice) {
    final bool isSelected = _isCustomSelected;
    final coins =
        (ref.watch(userProfileProvider).value?['coins'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: _busy ? null : _uploadAndApplyCustom,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.15), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isSelected &&
                        widget.currentBackgroundUrl != null &&
                        widget.currentBackgroundUrl!.isNotEmpty)
                      RoomBackgroundMedia(
                        url: widget.currentBackgroundUrl!,
                        fit: BoxFit.cover,
                        darkenAlpha: 0,
                      )
                    else
                      Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Iconsax.gallery_add,
                          size: 48,
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    if (_busy)
                      Container(
                        color: Colors.black26,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your background',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customPrice > 0 ? '$customPrice coins per apply' : 'Free',
                    style: TextStyle(
                      color: customPrice > 0 ? Colors.amber[800] : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Balance: ${NumberFormatter.format(coins)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to upload photo or SVGA',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decorationsAsync = ref.watch(roomDecorationsProvider);
    final customPriceAsync = ref.watch(roomCustomBackgroundPriceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
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
        title: const Text(
          'Room Decoration',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          decorationsAsync.when(
            data: (decorations) {
              final customPrice = customPriceAsync.value ?? 500;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: decorations.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCustomUploadCard(customPrice);
                  }

                  final decoration = decorations[index - 1];
                  final id = decoration['id']?.toString();
                  final bool isSelected =
                      !_isCustomSelected && _selectedDecorationId == id;
                  final price = _decorationPrice(decoration);

                  return GestureDetector(
                    onTap: _busy ? null : () => _applyCatalog(decoration),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(13),
                              ),
                              child: _buildDecorationPreview(decoration),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  decoration['name'] ?? 'Background',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (price > 0) ...[
                                      const Icon(
                                        Icons.stars,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$price coins',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ] else
                                      const Text(
                                        'Free',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
