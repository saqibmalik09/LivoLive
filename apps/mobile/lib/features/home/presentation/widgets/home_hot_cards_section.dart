import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/discovery_rooms_for_grid_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/widgets/ref_pag_loop.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

abstract final class HomePartyRoomFrames {
  static const rank1 = 'assets/home/hot-cards/party_frame_1.webp';
  static const rank2 = 'assets/home/hot-cards/party_frame_2.webp';
  static const rank3 = 'assets/home/hot-cards/party_frame_3.webp';

  static String forRank(int rank) {
    switch (rank) {
      case 1:
        return rank1;
      case 2:
        return rank2;
      case 3:
        return rank3;
      default:
        return '';
    }
  }
}

class HomeRoomTop3CardsSection extends ConsumerWidget {
  const HomeRoomTop3CardsSection({super.key});

  static const double sectionHeight = 248;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = ref.watch(homeTop3RankedRoomsProvider);
    final top1 = ranked[0];
    final top2 = ranked[1];
    final top3 = ranked[2];

    final isHomeTab =
        ref.watch(bottomNavIndexProvider) == bottomNavIndexForKey('home');
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxWidth / RefTop3Layout.designWidth;
        return SizedBox(
          height: RefTop3Layout.sectionHeight * s,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned.fill(child: RefSkyBackdrop(windowTop: 0)),
              for (final slot in RefTop3Layout.slots)
                Positioned(
                  left: slot.left * s,
                  top: slot.top * s,
                  width: slot.width * s,
                  height: slot.height * s,
                  child: _RefTop3Slot(
                    slot: slot,
                    room: switch (slot.rank) {
                      1 => top1,
                      2 => top2,
                      _ => top3,
                    },
                    animate: isHomeTab,
                    onTap: () => _openRoom(context, switch (slot.rank) {
                      1 => top1,
                      2 => top2,
                      _ => top3,
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Takes the room that is actually drawn on the card. Indexing back into the
  // unfiltered list opened the wrong room once a pinned room displaced the
  // automatic ordering.
  Future<void> _openRoom(
    BuildContext context,
    Map<String, dynamic>? displayed,
  ) async {
    if (displayed == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.home_noRankedRoom)));
      return;
    }
    final room = Map<String, dynamic>.from(displayed);
    final id = room['id']?.toString() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.home_noRankedRoom)));
      return;
    }
    try {
      await openRoomLive(context, room);
    } catch (e) {
      debugPrint('[RoomTop3] open room failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open room')));
    }
  }
}

class HomeHotCardsSection extends HomeRoomTop3CardsSection {
  const HomeHotCardsSection({super.key});
}

abstract final class RefTop3Layout {
  static const double designWidth = 750;

  static const double sectionHeight = 268;

  static const String cloudsAsset = 'assets/design/home/bg_sky_clouds.webp';
  static const String pedestalsAsset = 'assets/design/home/bg_pedestals_3.webp';

  static const double cloudsTop = -72;
  static const double cloudsHeight = 400;

  static const double pedestalsTop = 185;
  static const double pedestalsHeight = 146;

  static const double pagFrameWidthFix = 1 / 0.84;

  static const List<RefTop3Slot> slots = [
    RefTop3Slot(
      rank: 2,
      asset: 'assets/design/home/top2_room.pag',
      left: 43,
      top: 26,
      width: 184.5,
      height: 208.7,
      hole: (left: 0.135, top: 0.19, right: 0.128, bottom: 0.138),
    ),
    RefTop3Slot(
      rank: 1,
      asset: 'assets/design/home/top1_room.pag',
      left: 275.5,
      top: 11,
      width: 199,
      height: 227,
      hole: (left: 0.12, top: 0.19, right: 0.115, bottom: 0.143),
    ),
    RefTop3Slot(
      rank: 3,
      asset: 'assets/design/home/top3_room.pag',
      left: 523,
      top: 26,
      width: 183.5,
      height: 206.7,
      hole: (left: 0.136, top: 0.19, right: 0.125, bottom: 0.135),
    ),
  ];
}

class RefSkyBackdrop extends StatelessWidget {
  const RefSkyBackdrop({super.key, this.windowTop = 0, this.windowBottom});

  final double windowTop;

  final double? windowBottom;

  static const List<double> _cloudFade = [0, 72 / 400, 340 / 400, 1];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxWidth / RefTop3Layout.designWidth;
        final windowTop = windowBottom == null
            ? this.windowTop
            : windowBottom! - constraints.maxHeight / s;
        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: (RefTop3Layout.cloudsTop - windowTop) * s,
                left: 0,
                right: 0,
                height: RefTop3Layout.cloudsHeight * s,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: _cloudFade,
                    colors: [
                      Color(0x00000000),
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color(0x00000000),
                    ],
                  ).createShader(rect),
                  child: Image.asset(
                    RefTop3Layout.cloudsAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned(
                top: (RefTop3Layout.pedestalsTop - windowTop) * s,
                left: 0,
                right: 0,
                height: RefTop3Layout.pedestalsHeight * s,
                child: Image.asset(
                  RefTop3Layout.pedestalsAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RefTop3Slot {
  const RefTop3Slot({
    required this.rank,
    required this.asset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.hole,
  });

  final int rank;
  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;
  final ({double left, double top, double right, double bottom}) hole;
}

class _RefTop3Slot extends StatelessWidget {
  const _RefTop3Slot({
    required this.slot,
    required this.room,
    required this.animate,
    required this.onTap,
  });

  final RefTop3Slot slot;
  final Map<String, dynamic>? room;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = room?['image_url']?.toString().trim() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned(
                left: w * slot.hole.left,
                top: h * slot.hole.top,
                right: w * slot.hole.right,
                bottom: h * slot.hole.bottom,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: cover.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          transformWidth: 400,
                          transformHeight: 400,
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                          placeholder: (_, _) => const _PlaceholderBlock(),
                          errorWidget: (_, _, _) => const _PlaceholderBlock(),
                        )
                      : const _PlaceholderBlock(),
                ),
              ),
              Positioned(
                left: -w * (RefTop3Layout.pagFrameWidthFix - 1) / 2,
                right: -w * (RefTop3Layout.pagFrameWidthFix - 1) / 2,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: RefPagLoop(
                    asset: slot.asset,
                    width: w * RefTop3Layout.pagFrameWidthFix,
                    height: h,
                    active: animate,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PartyRoomRankCard extends StatelessWidget {
  const PartyRoomRankCard({
    super.key,
    required this.room,
    required this.rank,
    required this.onTap,
    required this.frameAsset,
  });

  final Map<String, dynamic>? room;
  final int rank;
  final VoidCallback onTap;
  final String frameAsset;

  ({double top, double bottom, double left, double right}) get _hole {
    switch (rank) {
      case 1:
        return (top: 0.052, bottom: 0.028, left: 0.036, right: 0.036);
      case 2:
        return (top: 0.078, bottom: 0.058, left: 0.044, right: 0.044);
      default:
        return (top: 0.078, bottom: 0.058, left: 0.044, right: 0.044);
    }
  }

  List<String> get _avatars {
    final raw = room?['top_avatars'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }

  int get _onlineCount => (room?['online_users_count'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final cover = room?['image_url']?.toString().trim() ?? '';
    final title = room?['title']?.toString().trim();
    final displayTitle = (title != null && title.isNotEmpty) ? title : '—';
    final hole = _hole;
    final avatars = _avatars;
    final onlineCount = _onlineCount;
    final showUsers = avatars.isNotEmpty || onlineCount > 0;
    final isLarge = rank == 1;

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              Positioned(
                left: w * hole.left,
                right: w * hole.right,
                top: h * hole.top,
                bottom: h * hole.bottom,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isLarge ? 6 : 4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover.isNotEmpty
                          ? AppNetworkImage(
                              imageUrl: cover,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              transformWidth: 400,
                              memCacheWidth: 400,
                              placeholder: (_, _) => const _PlaceholderBlock(),
                              errorWidget: (_, _, _) =>
                                  const _PlaceholderBlock(),
                            )
                          : const _PlaceholderBlock(),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            isLarge ? 6 : 4,
                            isLarge ? 16 : 12,
                            isLarge ? 6 : 4,
                            isLarge ? 5 : 3,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showUsers) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _AvatarCountPill(
                                    avatars: avatars,
                                    count: onlineCount,
                                    compact: !isLarge,
                                  ),
                                ),
                                SizedBox(height: isLarge ? 4 : 2),
                              ],
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isLarge ? 12 : 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (frameAsset.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.asset(
                      frameAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AvatarCountPill extends StatelessWidget {
  const _AvatarCountPill({
    required this.avatars,
    required this.count,
    this.compact = false,
  });

  final List<String> avatars;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 12.0 : 16.0;
    final overlap = compact ? 8.0 : 12.0;
    final fontSize = compact ? 8.0 : 10.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatars.isNotEmpty) ...[
            SizedBox(
              width: avatarSize + (avatars.length - 1) * overlap,
              height: avatarSize,
              child: Stack(
                children: List.generate(avatars.length, (i) {
                  return Positioned(
                    left: i * overlap,
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: ClipOval(
                        child: AppNetworkImage(
                          imageUrl: avatars[i],
                          transformWidth: 48,
                          transformHeight: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(width: compact ? 3 : 4),
          ],
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBlock extends StatelessWidget {
  const _PlaceholderBlock();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.accent.withValues(alpha: 0.2),
          ],
        ),
      ),
    );
  }
}
