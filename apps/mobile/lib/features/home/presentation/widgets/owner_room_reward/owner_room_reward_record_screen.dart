import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/owner_room_reward_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class OwnerRoomRewardRecordScreen extends ConsumerWidget {
  const OwnerRoomRewardRecordScreen({super.key, required this.roomId});

  final String roomId;

  static Future<void> open(BuildContext context, {required String roomId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerRoomRewardRecordScreen(roomId: roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(ownerRoomRewardClaimsProvider(roomId));

    return Scaffold(
      backgroundColor: const Color(0xFF12081F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
        ),
        title: const Text(
          'Owner Record',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
      ),
      body: claimsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (e, _) =>
            asyncErrorWidget(e, style: const TextStyle(color: Colors.white70)),
        data: (claims) {
          if (claims.isEmpty) {
            return const Center(
              child: Text(
                'No rewards yet',
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
              final date = c.createdAt == null
                  ? ''
                  : DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(c.createdAt!.toLocal());
              final subtitle = c.rewardType == 'coins'
                  ? '${NumberFormatter.format(c.coinAmount)} coins'
                  : c.title;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: c.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: c.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => const ColoredBox(
                                  color: Color(0xFF2A2A3A),
                                  child: Icon(
                                    Icons.card_giftcard,
                                    color: Colors.amber,
                                  ),
                                ),
                              )
                            : const ColoredBox(
                                color: Color(0xFF2A2A3A),
                                child: Icon(
                                  Icons.card_giftcard,
                                  color: Colors.amber,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lv${c.level} · ${c.title}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
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
