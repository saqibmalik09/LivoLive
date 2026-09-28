import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/features/home/presentation/widgets/agency_level_nameplate.dart';

class UserBadgeChip extends ConsumerWidget {
  final UserBadgeModel badge;
  final double? height;
  final bool emphasize;

  const UserBadgeChip({
    super.key,
    required this.badge,
    this.height,
    this.emphasize = false,
  });

  String? get _safeUrl {
    final raw = badge.imageUrl.trim();
    if (raw.isEmpty) return null;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      return null;
    }
    try {
      final uri = Uri.parse(raw);
      if (uri.host.isEmpty) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (badge.type == 'agency') {
      final h = height ?? 18;
      final plate = AgencyLevelNameplate(
        agencyName: badge.name,
        badgeUrl: _safeUrl ?? badge.imageUrl,
        height: h < 18 ? 18 : h,
        maxWidth: (h * 5.5).clamp(100.0, 160.0),
      );
      final agencyId = badge.refId?.trim() ?? '';
      if (agencyId.isEmpty) return plate;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            NavigationUtils.navigateToAgency(context, agencyId: agencyId),
        child: plate,
      );
    }

    final url = _safeUrl;
    if (url == null) return const SizedBox.shrink();

    final imageHeight =
        height ??
        (badge.type == 'vip'
            ? 12
            : (badge.type == 'title' || badge.type == 'medal' ? 20 : 18));

    final isTitleOrMedal = badge.type == 'title' || badge.type == 'medal';

    final image = CachedNetworkImage(
      imageUrl: url,
      height: imageHeight,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      fadeInDuration: const Duration(milliseconds: 180),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );

    Widget content = image;

    if (emphasize && isTitleOrMedal) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: content,
      );
    }

    return content;
  }
}
