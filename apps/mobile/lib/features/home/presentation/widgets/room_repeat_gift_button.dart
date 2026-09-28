import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/features/home/presentation/widgets/room_gift_sender.dart';

class RoomRepeatGiftButton extends StatefulWidget {
  final RepeatGiftSession session;
  final bool isSending;
  final VoidCallback onRepeat;
  final VoidCallback onDismiss;

  const RoomRepeatGiftButton({
    super.key,
    required this.session,
    required this.isSending,
    required this.onRepeat,
    required this.onDismiss,
  });

  @override
  State<RoomRepeatGiftButton> createState() => _RoomRepeatGiftButtonState();
}

class _RoomRepeatGiftButtonState extends State<RoomRepeatGiftButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isSending ? 1.0 : 1.0 + (_pulse.value * 0.04),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B9D), Color(0xFFFFB347)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: widget.isSending ? null : widget.onRepeat,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _giftThumb(session.giftIcon),
                  const SizedBox(width: 6),
                  _avatarThumb(session.targetAvatarUrl),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'x${session.quantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        session.targetUsername,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  widget.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.replay_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _giftThumb(String url) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white54, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : const Icon(Icons.card_giftcard, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _avatarThumb(String? url) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : const Icon(Icons.person, color: Colors.white70, size: 14),
      ),
    );
  }
}
