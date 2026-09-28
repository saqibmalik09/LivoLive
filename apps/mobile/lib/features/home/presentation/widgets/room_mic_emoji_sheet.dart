import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/room_mic_emoji_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/room_mic_emoji_sender.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomMicEmojiSheet extends ConsumerStatefulWidget {
  const RoomMicEmojiSheet({
    super.key,
    required this.roomId,
    required this.seatIndex,
    this.onSent,
  });

  final String roomId;
  final int seatIndex;
  final void Function(RoomMicEmoji emoji, String? messageId)? onSent;

  @override
  ConsumerState<RoomMicEmojiSheet> createState() => _RoomMicEmojiSheetState();
}

class _RoomMicEmojiSheetState extends ConsumerState<RoomMicEmojiSheet> {
  String? _sendingEmojiId;

  Future<void> _send(RoomMicEmoji emoji) async {
    if (_sendingEmojiId != null) return;
    setState(() => _sendingEmojiId = emoji.id);

    final result = await sendRoomMicEmoji(
      supabase: Supabase.instance.client,
      roomId: widget.roomId,
      emojiId: emoji.id,
      seatIndex: widget.seatIndex,
    );

    if (!mounted) return;

    if (result.success) {
      widget.onSent?.call(emoji, result.messageId);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not send emoji')),
      );
      setState(() => _sendingEmojiId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emojisAsync = ref.watch(roomMicEmojisForUserProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          emojisAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load emojis',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            data: (emojis) {
              if (emojis.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No emojis available',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return SizedBox(
                height: 240,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = emojis[index];
                    final sending = _sendingEmojiId == emoji.id;
                    return GestureDetector(
                      onTap: sending ? null : () => _send(emoji),
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CachedNetworkImage(
                            imageUrl: emoji.imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorWidget: (_, __, ___) => const Icon(
                              Iconsax.emoji_happy,
                              color: Colors.white38,
                              size: 28,
                            ),
                          ),
                          if (emoji.isPremium)
                            const Positioned(
                              top: 0,
                              right: 0,
                              child: Icon(
                                Icons.workspace_premium,
                                color: Colors.amber,
                                size: 12,
                              ),
                            ),
                          if (sending)
                            const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
