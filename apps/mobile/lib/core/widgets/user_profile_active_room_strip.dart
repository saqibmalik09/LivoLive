import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/user_active_room_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

class UserProfileActiveRoomStrip extends ConsumerWidget {
  const UserProfileActiveRoomStrip({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(userActiveRoomProvider(userId));

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox.shrink();

        final title = room['title']?.toString() ?? 'Live room';
        final imageUrl = room['image_url']?.toString();

        return Material(
          color: const Color(0xFF161625),
          child: InkWell(
            onTap: () {
              final ctx = AppRouter.navigatorKey.currentContext;
              if (ctx == null) return;
              openRoomLive(ctx, Map<String, dynamic>.from(room));
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                      ),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: const Color(0xFF252540),
                    ),
                    child: imageUrl == null
                        ? const Icon(
                            Icons.meeting_room,
                            color: Colors.white54,
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'In live room',
                          style: TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white54,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
