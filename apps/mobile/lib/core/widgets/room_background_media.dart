import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class RoomAssets {
  RoomAssets._();

  static const defaultBackground = 'assets/room/room-default-bg.webp';
}

class RoomDefaultBackground extends StatelessWidget {
  const RoomDefaultBackground({
    super.key,
    this.fit = BoxFit.cover,
    this.darkenAlpha = 0.45,
  });

  final BoxFit fit;
  final double darkenAlpha;

  @override
  Widget build(BuildContext context) {
    final media = Image.asset(
      RoomAssets.defaultBackground,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const _FallbackRoomGradient(),
    );

    if (darkenAlpha <= 0) return media;

    return Stack(
      fit: StackFit.expand,
      children: [
        media,
        ColoredBox(color: Colors.black.withValues(alpha: darkenAlpha)),
      ],
    );
  }
}

class _FallbackRoomGradient extends StatelessWidget {
  const _FallbackRoomGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B4E), Color(0xFF1A0A2E)],
        ),
      ),
    );
  }
}

class RoomBackgroundMedia extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double darkenAlpha;

  const RoomBackgroundMedia({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.darkenAlpha = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaUrlUtil.isSvgaUrl(url)
        ? RaveSVGAPlayer(resUrl: url, fit: fit, repeat: true)
        : CachedNetworkImage(imageUrl: url, fit: fit);

    if (darkenAlpha <= 0) return media;

    return Stack(
      fit: StackFit.expand,
      children: [
        media,
        ColoredBox(color: Colors.black.withValues(alpha: darkenAlpha)),
      ],
    );
  }
}
