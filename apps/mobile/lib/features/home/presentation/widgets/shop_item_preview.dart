import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/widgets/dynamic_chat_bubble.dart';
import 'package:sk_live/core/widgets/stretch_chat_bubble.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/gift_video_player.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/providers/shop_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class ShopItemPreview extends StatefulWidget {
  final ShopItem item;

  const ShopItemPreview({super.key, required this.item});

  @override
  State<ShopItemPreview> createState() => _ShopItemPreviewState();
}

class _ShopItemPreviewState extends State<ShopItemPreview> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initExternalSound();
  }

  Future<void> _initExternalSound() async {
    if (widget.item.soundUrl != null) {
      await _audioPlayer.play(UrlSource(widget.item.soundUrl!));
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.item.categoryName?.toLowerCase() == 'bubble'
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: DynamicChatBubble(
                        username: 'Preview User',
                        content:
                            'This is a preview of the ${widget.item.name}. It looks amazing!',
                        iconUrl:
                            isNineSliceChatBubble(
                              name: widget.item.name,
                              imageUrl: widget.item.imageUrl,
                            )
                            ? null
                            : widget.item.imageUrl,
                        frameUrl:
                            isNineSliceChatBubble(
                              name: widget.item.name,
                              imageUrl: widget.item.imageUrl,
                            )
                            ? widget.item.imageUrl
                            : null,
                        frameSvgaUrl: widget.item.svgaUrl,
                        bgColor: _getBubbleColor(widget.item.name, isBg: true),
                        borderColor: _getBubbleColor(
                          widget.item.name,
                          isBg: false,
                        ),
                        iconSize: 32,
                      ),
                    ),
                  )
                : MediaUrlUtil.isVideoUrl(widget.item.svgaUrl)
                ? GiftVideoPlayer(
                    url: widget.item.svgaUrl!,
                    muted: false,
                    repeat: true,
                  )
                : widget.item.svgaUrl != null
                ? RaveSVGAPlayer(
                    resUrl: widget.item.svgaUrl!,
                    fit: BoxFit.contain,
                  )
                : (widget.item.imageUrl != null &&
                          widget.item.imageUrl!.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: widget.item.imageUrl!,
                          fit: BoxFit.contain,
                          transformWidth: 512,
                          transformHeight: 512,
                          transformResize: 'contain',
                        )
                      : const Icon(
                          Icons.image,
                          size: 100,
                          color: Colors.white24,
                        )),
          ),

          if (_isLoading && widget.item.svgaUrl == null)
            const Center(child: CircularProgressIndicator(color: Colors.amber)),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.item.priceCoins} Coins',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        context.l10n.shop_purchaseNow,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
              onPressed: () => Navigator.pop(context),
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
