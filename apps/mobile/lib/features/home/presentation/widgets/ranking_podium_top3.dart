import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/podium_rank_frames_provider.dart';
import 'package:sk_live/core/providers/ranking_podium_preview_provider.dart';

import 'package:sk_live/core/widgets/ranking_frame_media.dart';

class RankingPodiumTop3 extends StatelessWidget {
  const RankingPodiumTop3({
    super.key,
    required this.entries,
    this.framesByRank = const {},
    this.isRoom = false,
    this.onTapEntry,
    this.rank1Top = 10,
    this.compact = false,
  });

  final List<RankingPodiumEntry> entries;
  final Map<int, PodiumRankFrame> framesByRank;
  final bool isRoom;
  final void Function(RankingPodiumEntry entry)? onTapEntry;
  final double rank1Top;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final slots = List<RankingPodiumEntry?>.from(entries);
    while (slots.length < 3) {
      slots.add(null);
    }

    final rank1Size = compact ? 68.0 : 140.0;
    final sideSize = compact ? 40.0 : 80.0;
    final stackHeight = compact ? rank1Size + 12 : rank1Size;
    return SizedBox(
      height: stackHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.hardEdge,
        children: [
          if (slots.length > 1)
            Positioned(
              left: compact ? 0 : 2,
              bottom: compact ? 0 : 2,
              child: _buildRankSlot(slots[1], 2, sideSize),
            ),
          if (slots.length > 2)
            Positioned(
              right: compact ? 0 : 2,
              bottom: compact ? 0 : 2,
              child: _buildRankSlot(slots[2], 3, sideSize),
            ),
          if (slots.isNotEmpty)
            Positioned(
              top: compact ? 0 : rank1Top,
              child: _buildRankSlot(slots[0], 1, rank1Size),
            ),
        ],
      ),
    );
  }

  Widget _buildRankSlot(RankingPodiumEntry? entry, int rank, double frameSize) {
    final avatarSize = frameSize * (rank == 1 ? 0.22 : 0.28);
    final adminFrame = framesByRank[rank];
    final avatarRadius = isRoom ? avatarSize * 0.18 : avatarSize / 2;

    final String frameUrl;
    final bool frameIsSvga;
    if (framesByRank.isNotEmpty) {
      frameUrl = adminFrame?.url.trim() ?? '';
      frameIsSvga = adminFrame?.isSvga ?? false;
    } else {
      frameUrl = entry?.frameUrl?.trim() ?? '';
      frameIsSvga = false;
    }

    Widget avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(avatarRadius),
        color: Colors.black26,
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(avatarRadius),
        child: entry?.avatarUrl != null && entry!.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: entry.avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Icon(
                  isRoom ? Icons.meeting_room : Icons.person,
                  color: Colors.white54,
                  size: avatarSize * 0.4,
                ),
              )
            : Icon(
                isRoom ? Icons.meeting_room : Icons.person,
                color: Colors.white24,
                size: avatarSize * 0.45,
              ),
      ),
    );

    if (entry != null && onTapEntry != null) {
      avatar = GestureDetector(onTap: () => onTapEntry!(entry), child: avatar);
    }

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          if (frameUrl.isNotEmpty)
            IgnorePointer(
              child: RankingFrameMedia(
                url: frameUrl,
                isSvga: frameIsSvga ? true : null,
                width: frameSize,
                height: frameSize,
                fit: BoxFit.contain,
              ),
            ),
          Transform.translate(
            offset: Offset(0, frameSize * 0.04),
            child: avatar,
          ),
        ],
      ),
    );
  }
}
