import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
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
      error: (_, __) => const SizedBox.shrink(),
      data: (bySlot) {
        if (bySlot.isEmpty) return const SizedBox.shrink();

        Map<String, dynamic>? at(int slot) => bySlot[slot];

        final top1 = at(1);
        final top2 = at(2);
        final top3 = at(3);
        if (top1 == null && top2 == null && top3 == null) {
          return const SizedBox.shrink();
        }

        Future<void> openSlot(int slot) async {
          final room = at(slot);
          if (room == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.home_noRankedRoom)),
            );
            return;
          }
          try {
            await openRoomLive(context, Map<String, dynamic>.from(room));
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
                      onTap: () => openSlot(1),
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
                            onTap: () => openSlot(2),
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
                            onTap: () => openSlot(3),
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
      },
    );
  }
}
