import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';

import 'package:sk_live/core/util/media_url_util.dart';

import 'package:sk_live/core/widgets/svga_player.dart';

class RankingFrameMedia extends StatelessWidget {
  const RankingFrameMedia({
    super.key,

    required this.url,

    this.isSvga,

    this.width,

    this.height,

    this.fit = BoxFit.contain,
  });

  final String url;

  final bool? isSvga;

  final double? width;

  final double? height;

  final BoxFit fit;

  bool get _useSvga => isSvga ?? MediaUrlUtil.isSvgaUrl(url);

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();

    if (trimmed.isEmpty) return const SizedBox.shrink();

    if (_useSvga) {
      return SizedBox(
        width: width,

        height: height,

        child: Stack(
          alignment: Alignment.center,

          children: [
            if (width != null && height != null)
              SizedBox(
                width: width,

                height: height,

                child: const ColoredBox(color: Colors.transparent),
              ),

            RaveSVGAPlayer(resUrl: trimmed, fit: fit, repeat: true),
          ],
        ),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width == null ? null : (width! * dpr).round();
    final cacheH = height == null ? null : (height! * dpr).round();

    return CachedNetworkImage(
      imageUrl: trimmed,

      width: width,

      height: height,

      fit: fit,

      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,

      placeholder: (_, _) => const SizedBox.shrink(),

      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
