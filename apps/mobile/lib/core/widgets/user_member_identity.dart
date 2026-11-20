import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';

/// Still frame (or nothing, so the avatar shows) on the first paint.
/// The looping SVGA player mounts only after that frame, and only while
/// this widget is still in the tree.
class DeferredSeatFrame extends StatefulWidget {
  const DeferredSeatFrame({
    super.key,
    required this.imageUrl,
    required this.svgaUrl,
    this.memCacheWidth,
  });

  final String? imageUrl;
  final String? svgaUrl;
  final int? memCacheWidth;

  @override
  State<DeferredSeatFrame> createState() => _DeferredSeatFrameState();
}

class _DeferredSeatFrameState extends State<DeferredSeatFrame> {
  bool _playSvga = false;
  bool _svgaReady = false;

  bool get _hasImage {
    final url = widget.imageUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  bool get _hasSvga {
    final url = widget.svgaUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _scheduleSvga();
  }

  @override
  void didUpdateWidget(DeferredSeatFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgaUrl != widget.svgaUrl) {
      _playSvga = false;
      _svgaReady = false;
      _scheduleSvga();
    }
  }

  void _scheduleSvga() {
    if (!_hasSvga) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasSvga) return;
      setState(() => _playSvga = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasImage && !_hasSvga) return const SizedBox.shrink();
    final cache = widget.memCacheWidth;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasImage && !_svgaReady)
          AppNetworkImage(
            imageUrl: widget.imageUrl!.trim(),
            fit: BoxFit.contain,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            memCacheWidth: cache,
            memCacheHeight: cache,
            transformWidth: cache ?? 180,
            transformHeight: cache ?? 180,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        if (_playSvga && _hasSvga)
          RaveSVGAPlayer(
            resUrl: widget.svgaUrl!.trim(),
            fit: BoxFit.contain,
            repeat: true,
            onLoaded: () {
              if (!mounted || _svgaReady) return;
              setState(() => _svgaReady = true);
            },
          ),
      ],
    );
  }
}

class UserMemberBadgesRow extends ConsumerWidget {
  const UserMemberBadgesRow({
    super.key,
    required this.userId,
    this.maxBadges = 20,
  });

  final String userId;
  final int maxBadges;

  static const double rowHeight = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final badgesAsync = ref.watch(userBadgesProvider(userId));
    return badgesAsync.when(
      data: (badges) {
        if (badges.isEmpty) return const SizedBox.shrink();

        final agencyBadges = badges.where((b) => b.type == 'agency').toList();
        final levelBadges = badges
            .where(
              (b) =>
                  b.type != 'medal' &&
                  b.type != 'title' &&
                  b.type != 'agency' &&
                  b.imageUrl.trim().isNotEmpty,
            )
            .toList();
        final titleBadges = badges.where((b) => b.type == 'title').toList();
        final medalBadges = badges.where((b) => b.type == 'medal').toList();

        final ordered = [
          ...agencyBadges,
          ...levelBadges,
          ...titleBadges,
          ...medalBadges,
        ].take(maxBadges).toList();

        if (ordered.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: ordered.map((b) {
            final h = b.type == 'agency'
                ? 18.0
                : (b.type == 'title'
                      ? 14.0
                      : (b.type == 'medal' ? 18.0 : 16.0));
            return UserBadgeChip(badge: b, height: h);
          }).toList(),
        );
      },
      loading: () => const SizedBox(height: rowHeight),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class UserFramedAvatar extends ConsumerWidget {
  const UserFramedAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.radius = 22,
  });

  final String userId;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarBox = radius * 2;
    final frameSize = avatarBox * 1.8;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final avatarDecodePx = (avatarBox * dpr).round().clamp(32, 256);
    final frameDecodePx = (frameSize * dpr).round().clamp(32, 320);

    return SizedBox(
      // The laid-out footprint stays the avatar's size so seat and list
      // spacing is unchanged; the frame simply overflows it.
      width: avatarBox,
      height: avatarBox,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white12,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(
                    avatarUrl!,
                    maxWidth: avatarDecodePx,
                    maxHeight: avatarDecodePx,
                  )
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(Icons.person, color: Colors.white38, size: radius)
                : null,
          ),
          if (userId.isNotEmpty)
            Consumer(
              builder: (context, ref, _) {
                final frameAsync = ref.watch(userEquippedFrameProvider(userId));
                return frameAsync.when(
                  data: (frame) {
                    if (frame == null) return const SizedBox.shrink();
                    final imageUrl = frame['image_url']?.toString();
                    final svgaUrl = frame['svga_url']?.toString();
                    if ((imageUrl == null || imageUrl.isEmpty) &&
                        (svgaUrl == null || svgaUrl.isEmpty)) {
                      return const SizedBox.shrink();
                    }
                    return IgnorePointer(
                      // OverflowBox is what actually lets the frame exceed the
                      // avatar. The Stack hands its children the parent's
                      // constraints, so a plain SizedBox larger than the box is
                      // simply squeezed back down to it — Clip.none only stops
                      // clipping while painting, it does not loosen layout.
                      child: OverflowBox(
                        maxWidth: frameSize,
                        maxHeight: frameSize,
                        child: SizedBox(
                          width: frameSize,
                          height: frameSize,
                          child: DeferredSeatFrame(
                            imageUrl: imageUrl,
                            svgaUrl: svgaUrl,
                            memCacheWidth: frameDecodePx,
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
        ],
      ),
    );
  }
}
