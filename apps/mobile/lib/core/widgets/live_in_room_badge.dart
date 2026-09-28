import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/user_active_room_provider.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

enum LiveInRoomBadgeStyle { floating, avatarOverlay }

class LiveInRoomBadge extends ConsumerWidget {
  const LiveInRoomBadge({
    super.key,
    this.userId,
    this.room,
    this.style = LiveInRoomBadgeStyle.floating,
  }) : assert(userId != null || room != null);

  final String? userId;
  final Map<String, dynamic>? room;
  final LiveInRoomBadgeStyle style;

  static void openRoom(BuildContext context, Map<String, dynamic> room) {
    openRoomLive(context, Map<String, dynamic>.from(room));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (room != null) {
      return _LiveInRoomBadgeContent(room: room!, style: style);
    }

    final roomAsync = ref.watch(userActiveRoomProvider(userId!));
    return roomAsync.when(
      data: (activeRoom) {
        if (activeRoom == null) return const SizedBox.shrink();
        return _LiveInRoomBadgeContent(room: activeRoom, style: style);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LiveInRoomBadgeContent extends StatelessWidget {
  const _LiveInRoomBadgeContent({required this.room, required this.style});

  final Map<String, dynamic> room;
  final LiveInRoomBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    final compact = style == LiveInRoomBadgeStyle.avatarOverlay;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => LiveInRoomBadge.openRoom(context, room),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 8,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                blurRadius: compact ? 6 : 10,
              ),
            ],
          ),
          child: compact
              ? const _EqualizerBars(height: 14, barWidth: 2)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _EqualizerBars(height: 18, barWidth: 2.5),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: const Color(0xFF00E5FF),
                        fontSize: compact ? 8 : 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EqualizerBars extends StatefulWidget {
  const _EqualizerBars({required this.height, required this.barWidth});

  final double height;
  final double barWidth;

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with TickerProviderStateMixin {
  static const _barCount = 3;
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_barCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + i * 120),
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_barCount, (i) {
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, _) {
              final minH = widget.height * 0.35;
              final maxH = widget.height;
              final h = minH + _controllers[i].value * (maxH - minH);
              return Container(
                width: widget.barWidth,
                height: h,
                margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF),
                  borderRadius: BorderRadius.circular(widget.barWidth),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class AvatarWithLiveRoomBadge extends StatelessWidget {
  const AvatarWithLiveRoomBadge({
    super.key,
    required this.avatar,
    this.activeRoom,
    this.userId,
  });

  final Widget avatar;
  final Map<String, dynamic>? activeRoom;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (activeRoom != null)
          Positioned(
            right: -2,
            top: -2,
            child: LiveInRoomBadge(
              room: activeRoom,
              style: LiveInRoomBadgeStyle.avatarOverlay,
            ),
          )
        else if (userId != null)
          Positioned(
            right: -2,
            top: -2,
            child: LiveInRoomBadge(
              userId: userId,
              style: LiveInRoomBadgeStyle.avatarOverlay,
            ),
          ),
      ],
    );
  }
}
