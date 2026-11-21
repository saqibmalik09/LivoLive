import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/party_screen_config_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/app_image_cache.dart';

class PartyScreenBackground extends ConsumerWidget {
  const PartyScreenBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.partyPageBg),
        DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.partyScreenGradient),
        ),
        _TopBandImage(),
      ],
    );
  }
}

class _TopBandImage extends ConsumerWidget {
  const _TopBandImage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config =
        ref.watch(partyScreenConfigProvider).valueOrNull ??
        PartyScreenConfig.empty();
    final topHeight = MediaQuery.paddingOf(context).top + 16;

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: topHeight,
        width: double.infinity,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.white,
              Color(0xEEFFFFFF),
              Color(0x99FFFFFF),
              Color(0x44FFFFFF),
              Colors.transparent,
            ],
            stops: [0.0, 0.15, 0.35, 0.55, 0.78, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: config.topImageUrl.isNotEmpty
              ? CachedNetworkImage(
                  cacheManager: AppImageCache.manager,
                  imageUrl: config.versionedTopUrl,
                  cacheKey: 'party_top_${config.cacheVersion}',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, __) => Image.asset(
                    PartyScreenConfig.fallbackTopAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  errorWidget: (_, __, ___) => Image.asset(
                    PartyScreenConfig.fallbackTopAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                )
              : Image.asset(
                  PartyScreenConfig.fallbackTopAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
        ),
      ),
    );
  }
}
