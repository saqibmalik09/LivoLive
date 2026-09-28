import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/services/room_exit_coordinator.dart';
import 'package:sk_live/core/widgets/fast_circle_avatar.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

class MinimizedRoomOverlayHost extends ConsumerStatefulWidget {
  const MinimizedRoomOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MinimizedRoomOverlayHost> createState() =>
      _MinimizedRoomOverlayHostState();
}

class _MinimizedRoomOverlayHostState
    extends ConsumerState<MinimizedRoomOverlayHost> {
  Offset? _bubblePos;

  static const double _box = 98;
  static const double _hit = _box + 22;

  @override
  Widget build(BuildContext context) {
    final minimizedRoom = ref.watch(minimizedRoomProvider);
    final liveRoomId = ref.watch(currentLiveRoomIdProvider);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    final minLeft = 8.0;
    final maxLeft = size.width - _hit - 8;
    final minTop = padding.top + 8;
    final maxTop = size.height - _hit - padding.bottom - 72;
    final defaultLeft = maxLeft.clamp(minLeft, size.width).toDouble();
    final defaultTop = (size.height * 0.36).clamp(minTop, maxTop).toDouble();

    final left = (_bubblePos?.dx ?? defaultLeft)
        .clamp(minLeft, maxLeft)
        .toDouble();
    final top = (_bubblePos?.dy ?? defaultTop).clamp(minTop, maxTop).toDouble();

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (minimizedRoom != null && liveRoomId == null)
          Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  final current = _bubblePos ?? Offset(defaultLeft, defaultTop);
                  _bubblePos = Offset(
                    (current.dx + details.delta.dx)
                        .clamp(minLeft, maxLeft)
                        .toDouble(),
                    (current.dy + details.delta.dy)
                        .clamp(minTop, maxTop)
                        .toDouble(),
                  );
                });
              },
              onPanEnd: (_) {
                final current = _bubblePos ?? Offset(defaultLeft, defaultTop);
                final snapLeft = current.dx + _hit / 2 < size.width / 2;
                setState(() {
                  _bubblePos = Offset(snapLeft ? minLeft : maxLeft, current.dy);
                });
              },
              child: _MinimizedRoomBubble(room: minimizedRoom),
            ),
          ),
      ],
    );
  }
}

class _MinimizedRoomBubble extends ConsumerStatefulWidget {
  const _MinimizedRoomBubble({required this.room});

  final Map<String, dynamic> room;

  @override
  ConsumerState<_MinimizedRoomBubble> createState() =>
      _MinimizedRoomBubbleState();
}

class _MinimizedRoomBubbleState extends ConsumerState<_MinimizedRoomBubble>
    with SingleTickerProviderStateMixin {
  bool _isClosing = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _closeMinimizedRoom() async {
    if (_isClosing) return;
    setState(() => _isClosing = true);

    final roomId = widget.room['id']?.toString();
    if (roomId == null) {
      clearActiveRoomState(ref);
      return;
    }

    await RoomExitCoordinator.leaveRoom(ref, roomId: roomId);

    if (!mounted) return;
    setState(() => _isClosing = false);
  }

  void _returnToRoom() {
    if (_isClosing) return;
    final roomId = widget.room['id']?.toString();
    if (roomId != null) {
      ref.read(currentLiveRoomIdProvider.notifier).state = roomId;
      ref.read(minimizedRoomProvider.notifier).state = null;
      ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
    }
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx == null) return;
    openRoomLive(
      ctx,
      Map<String, dynamic>.from(widget.room),
      skipLockCheck: true,
    );
  }

  String? _avatarUrl() {
    final fromRoom = widget.room['_bubble_avatar']?.toString().trim();
    if (fromRoom != null && fromRoom.isNotEmpty) return fromRoom;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final fromProfile = profile?['avatar_url']?.toString().trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    final roomImage =
        (widget.room['image_url'] ?? widget.room['background_url'])
            ?.toString()
            .trim();
    if (roomImage != null && roomImage.isNotEmpty) return roomImage;
    return null;
  }

  int _vipLevel() {
    final stored = (widget.room['_bubble_vip'] as num?)?.toInt();
    if (stored != null && stored > 0) return stored;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    return (profile?['vip_level'] as num?)?.toInt() ?? 0;
  }

  bool _isMuted() => widget.room['_bubble_muted'] == true;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl();
    final vipLevel = _vipLevel();
    final muted = _isMuted();

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 118,
        height: 118,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 12,
              child: GestureDetector(
                onTap: _returnToRoom,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_pulse.value);
                    return Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFE08A),
                            Color(0xFFFF4D8D),
                            Color(0xFF7B61FF),
                            Color(0xFFFFD54F),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF4D8D,
                            ).withValues(alpha: 0.28 + t * 0.22),
                            blurRadius: 16 + t * 8,
                            spreadRadius: 0.5,
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFFFFD54F,
                            ).withValues(alpha: 0.18 + t * 0.14),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.2),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2A1458),
                          Color(0xFF12081F),
                          Color(0xFF1A0A2E),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          left: 10,
                          child: Container(
                            width: 28,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: _FramedAvatar(
                            url: avatarUrl,
                            vipLevel: vipLevel,
                            pulse: _pulse,
                          ),
                        ),
                        Positioned(
                          right: 7,
                          bottom: 7,
                          child: _MicChip(muted: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: _isClosing ? null : _closeMinimizedRoom,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6B6B), Color(0xFFE53935)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isClosing
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicChip extends StatelessWidget {
  const _MicChip({required this.muted});

  final bool muted;

  @override
  Widget build(BuildContext context) {
    final live = !muted;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: live
              ? const [Color(0xFF7CFFB2), Color(0xFF00C853)]
              : const [Color(0xFFFF8A80), Color(0xFFE53935)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (live ? const Color(0xFF00C853) : const Color(0xFFE53935))
                .withValues(alpha: 0.45),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(
        live ? Icons.mic_rounded : Icons.mic_off_rounded,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}

class _FramedAvatar extends ConsumerWidget {
  const _FramedAvatar({
    required this.url,
    required this.vipLevel,
    required this.pulse,
  });

  final String? url;
  final int vipLevel;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const avatarSize = 60.0;
    final frameAsync = vipLevel > 0
        ? ref.watch(vipFrameProvider(vipLevel))
        : null;
    final frameUrl = frameAsync?.valueOrNull;

    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(pulse.value);
              return Container(
                width: avatarSize + 10 + t * 2,
                height: avatarSize + 10 + t * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFFFF3C4),
                      Color(0xFFFFD54F),
                      Color(0xFFFF4D8D),
                      Color(0xFF7B61FF),
                      Color(0xFFFF8A00),
                      Color(0xFFFFF3C4),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFFD54F,
                      ).withValues(alpha: 0.22 + t * 0.2),
                      blurRadius: 8 + t * 6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.6),
                child: child,
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF12081F),
              ),
              padding: const EdgeInsets.all(1.6),
              child: FastCircleAvatar(
                radius: avatarSize / 2,
                imageUrl: url,
                backgroundColor: const Color(0xFF2A1458),
                fallback: const Icon(
                  Icons.person,
                  color: Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ),
          if (frameUrl != null && frameUrl.isNotEmpty)
            IgnorePointer(
              child: SizedBox(
                width: 78,
                height: 78,
                child: CachedNetworkImage(
                  imageUrl: frameUrl,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
