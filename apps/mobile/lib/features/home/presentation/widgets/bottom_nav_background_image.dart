import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/party_screen_config_provider.dart';

class BottomNavBackgroundImage extends StatelessWidget {
  const BottomNavBackgroundImage({super.key, required this.config});

  final PartyScreenConfig config;

  @override
  Widget build(BuildContext context) {
    return _buildImage();
  }

  Widget _buildImage() {
    if (config.bottomImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: config.versionedBottomUrl,
        cacheKey: 'party_bottom_nav_${config.cacheVersion}',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Image.asset(
      PartyScreenConfig.fallbackBottomAsset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
  }
}
