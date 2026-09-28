import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/room_reward_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/features/home/presentation/widgets/room_reward/room_reward_assets.dart';
import 'package:sk_live/features/home/presentation/widgets/room_reward/room_reward_gift_sheet.dart';

class RoomRewardFloatButton extends ConsumerStatefulWidget {
  const RoomRewardFloatButton({
    super.key,
    required this.roomId,
    this.size = 56,
  });

  final String roomId;
  final double size;

  @override
  ConsumerState<RoomRewardFloatButton> createState() =>
      _RoomRewardFloatButtonState();
}

class _RoomRewardFloatButtonState extends ConsumerState<RoomRewardFloatButton> {
  Timer? _tick;
  bool _refreshingOnExpire = false;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTicker(RoomRewardProgress progress) {
    final open = progress.openClaimLevel;
    final needs = open != null && open.liveClaimSecondsRemaining() > 0;
    if (!needs) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick?.isActive == true) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final p = ref.read(roomRewardProgressProvider(widget.roomId)).valueOrNull;
      final left = p?.openClaimLevel?.liveClaimSecondsRemaining() ?? 0;
      if (left <= 0) {
        _tick?.cancel();
        _tick = null;
        if (!_refreshingOnExpire) {
          _refreshingOnExpire = true;
          ref.invalidate(roomRewardProgressProvider(widget.roomId));
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            _refreshingOnExpire = false;
          });
        }
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(roomRewardProgressProvider(widget.roomId));
    final progress = progressAsync.valueOrNull ?? RoomRewardProgress.empty();
    _syncTicker(progress);
    final open = progress.openClaimLevel;
    final level = progress.focusLevel.clamp(1, progress.maxLevel);
    final levelInfo = progress.levelInfo(level);
    final required = levelInfo?.requiredPoints ?? 1;
    final ratio = progress.progressForLevel(level);
    final claimSecs = open?.liveClaimSecondsRemaining() ?? 0;
    final claimReady = open != null && claimSecs > 0;
    final size = widget.size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.invalidate(roomRewardProgressProvider(widget.roomId));
        RoomRewardGiftSheet.show(context, roomId: widget.roomId);
      },
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: IgnorePointer(
                child: RaveSVGAPlayer(
                  key: ValueKey('float_box_$level'),
                  resUrl: RoomRewardAssets.shelfBoxSvga(level),
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              claimReady ? 'Claim!' : 'Lv$level',
              style: TextStyle(
                color: claimReady
                    ? const Color(0xFFFF6F00)
                    : const Color(0xFFFFE082),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 4,
                width: size,
                child: LinearProgressIndicator(
                  value: claimReady ? 1 : ratio,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(
                    claimReady
                        ? const Color(0xFFFF6F00)
                        : const Color(0xFFFFD54F),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              claimReady
                  ? _floatCountdown(claimSecs)
                  : '${NumberFormatter.format(progress.energy)}/${NumberFormatter.format(required)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: claimReady ? const Color(0xFFFFE082) : Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _floatCountdown(int seconds) {
  final s = seconds.clamp(0, 999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
