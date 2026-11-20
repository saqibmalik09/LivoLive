import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/pinned_party_rooms_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/home_hot_cards_section.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

class HomePinnedRoomsSection extends ConsumerWidget {
  const HomePinnedRoomsSection({super.key});

  static const double sectionHeight = HomeRoomTop3CardsSection.sectionHeight;
  static const double _framePad = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRooms = ref.watch(pinnedPartyRoomsProvider);

    return asyncRooms.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (bySlot) {
        if (bySlot.isEmpty) return const SizedBox.shrink();

        Map<String, dynamic>? at(int slot) => bySlot[slot];

        // One featured room, full width. This used to be a big left card beside
        // two smaller ones; when fewer than three rooms were pinned the unused
        // ones drew as empty frames. Falling through the slots keeps any room
        // pinned under the old three-slot scheme visible.
        final featured = at(1) ?? at(2) ?? at(3);
        if (featured == null) {
          return const SizedBox.shrink();
        }

        Future<void> openFeatured() async {
          try {
            await openRoomLive(context, Map<String, dynamic>.from(featured));
          } catch (e) {
            debugPrint('[PinnedSlot] open failed: $e');
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open room')),
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
          child: SizedBox(
            height: sectionHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                2,
                _framePad,
                2,
                _framePad,
              ),
              child: PartyRoomRankCard(
                room: featured,
                rank: 1,
                frameAsset: HomePartyRoomFrames.rank1,
                onTap: openFeatured,
              ),
            ),
          ),
        );
      },
    );
  }
}
