import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/discovery_rooms_for_grid_provider.dart';
import 'package:sk_live/core/providers/home_rooms_pagination_provider.dart';
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
  static const double _framePad = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(discoveryRoomsPaginationProvider);
    final topRooms = ref.watch(discoveryTop3RoomsProvider);

    if (roomsState.isLoading && topRooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.zero,
        child: SizedBox(height: sectionHeight, child: _PlaceholderBlock()),
      );
    }

    Map<String, dynamic>? at(int rank) {
      if (topRooms.length < rank) return null;
      return topRooms[rank - 1];
    }

    final top1 = at(1);
    final top2 = at(2);
    final top3 = at(3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: SizedBox(
        height: sectionHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 13,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  2,
                  _framePad,
                  _framePad,
                  _framePad,
                ),
                child: PartyRoomRankCard(
                  room: top1,
                  rank: 1,
                  frameAsset: HomePartyRoomFrames.rank1,
                  onTap: () => _openRoom(context, topRooms, 0),
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        _framePad,
                        2,
                        _framePad / 2,
                      ),
                      child: PartyRoomRankCard(
                        room: top2,
                        rank: 2,
                        frameAsset: HomePartyRoomFrames.rank2,
                        onTap: () => _openRoom(context, topRooms, 1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        _framePad / 2,
                        2,
                        _framePad,
                      ),
                      child: PartyRoomRankCard(
                        room: top3,
                        rank: 3,
                        frameAsset: HomePartyRoomFrames.rank3,
                        onTap: () => _openRoom(context, topRooms, 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRoom(
    BuildContext context,
    List<Map<String, dynamic>> topRooms,
    int index,
  ) async {
    if (index < 0 || index >= topRooms.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.home_noRankedRoom)));
      return;
    }
    final room = Map<String, dynamic>.from(topRooms[index]);
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
