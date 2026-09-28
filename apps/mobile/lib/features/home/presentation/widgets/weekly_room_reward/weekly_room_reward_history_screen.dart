import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/weekly_room_reward_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class WeeklyRoomRewardHistoryScreen extends ConsumerWidget {
  const WeeklyRoomRewardHistoryScreen({super.key, required this.roomId});

  final String roomId;

  static Future<void> open(BuildContext context, {required String roomId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeeklyRoomRewardHistoryScreen(roomId: roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(weeklyRoomRewardClaimsProvider(roomId));

    return Scaffold(
      backgroundColor: const Color(0xFF1A080E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
        ),
        title: const Text(
          'Reward History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
      ),
      body: claimsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
        ),
        error: (e, _) =>
            asyncErrorWidget(e, style: const TextStyle(color: Colors.white70)),
        data: (claims) {
          if (claims.isEmpty) {
            return const Center(
              child: Text(
                'No claims yet',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: claims.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final c = claims[index];
              final date = c.claimedAt == null
                  ? ''
                  : DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(c.claimedAt!.toLocal());
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A101C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD4A84B).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lv${c.level} · Week ${c.periodKey}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.coinAmount} coins',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (date.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              date,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
