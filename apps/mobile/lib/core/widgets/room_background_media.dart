import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/app_image_cache.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class RoomAssets {
  RoomAssets._();

  static const defaultBackground = 'assets/room/room-default-bg.webp';
}

/// Opaque room color painted before a theme image decodes.
const Color roomBackdropColor = Color(0xFF1A0A2E);

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
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: roomBackdropColor),
        Image.asset(
          RoomAssets.defaultBackground,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => const _FallbackRoomGradient(),
        ),
        if (darkenAlpha > 0)
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
    final decodePx = _backgroundCachePx(context);
    // The room background was the one image in the app loaded at its source
    // resolution: a host can upload a 6000px photo, and the full multi-MB file
    // was downloaded on every room entry. memCacheWidth below only bounds the
    // decode, not the transfer. Asking Supabase to render it at the width we
    // are about to decode to turns that into a webp of a few hundred KB.
    final imageUrl =
        SupabaseImageTransform.url(url, width: decodePx, quality: 80) ?? url;
    final media = MediaUrlUtil.isSvgaUrl(url)
        ? RaveSVGAPlayer(resUrl: url, fit: fit, repeat: true)
        : CachedNetworkImage(
            cacheManager: AppImageCache.manager,
            imageUrl: imageUrl,
            fit: fit,
            fadeInDuration: Duration.zero,
            // Default fade-out is 1s and sits on top of the image.
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => const ColoredBox(color: roomBackdropColor),
            // Fills the room screen, so bound the decode to the actual
            // device size instead of the source image's full resolution —
            // this still background is the first thing painted on room
            // entry, before any seat/frame content arrives.
            memCacheWidth: decodePx,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: roomBackdropColor),
        media,
        if (darkenAlpha > 0)
          ColoredBox(color: Colors.black.withValues(alpha: darkenAlpha)),
      ],
    );
  }
}

int _backgroundCachePx(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (width * dpr).round().clamp(720, 1440);
}
