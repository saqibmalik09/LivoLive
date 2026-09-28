import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/weekly_room_reward_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_assets.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_sheet.dart';

class WeeklyRoomRewardFloatButton extends ConsumerWidget {
  const WeeklyRoomRewardFloatButton({
    super.key,
    required this.roomId,
    this.size = 56,
  });

  final String roomId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(weeklyRoomRewardProgressProvider(roomId));
    final progress =
        progressAsync.valueOrNull ?? WeeklyRoomRewardProgress.empty();
    final next = progress.currentWeekFocusLevel;
    final required = next?.requiredPoints ?? 1;
    final ratio = (progress.charm / required).clamp(0.0, 1.0);
    final level = next?.level ?? 1;
    final showClaimHint =
        progress.inClaimWindow && progress.claimableLevel != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.invalidate(weeklyRoomRewardProgressProvider(roomId));
        WeeklyRoomRewardSheet.show(context, roomId: roomId);
      },
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    WeeklyRoomRewardAssets.cupButton,
                    fit: BoxFit.contain,
                  ),
                  if (showClaimHint)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF81C784),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Lv$level',
              style: const TextStyle(
                color: Color(0xFFFFE082),
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
                  value: ratio,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD54F)),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${NumberFormatter.format(progress.charm)}/${NumberFormatter.format(required)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
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
