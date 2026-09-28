import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/team_pk_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_theme.dart';

class TeamPkSettingSheet extends StatefulWidget {
  const TeamPkSettingSheet({
    super.key,
    required this.roomId,
    required this.onStarted,
  });

  final String roomId;
  final VoidCallback onStarted;

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required VoidCallback onStarted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          TeamPkSettingSheet(roomId: roomId, onStarted: onStarted),
    );
  }

  @override
  State<TeamPkSettingSheet> createState() => _TeamPkSettingSheetState();
}

class _TeamPkSettingSheetState extends State<TeamPkSettingSheet> {
  int _durationMinutes = 5;
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final result = await TeamPkService.startSession(
        roomId: widget.roomId,
        durationMinutes: _durationMinutes,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context);
        widget.onStarted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team PK started ($_durationMinutes min)'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to start'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Iconsax.arrow_left, color: Colors.white70),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                visualDensity: VisualDensity.compact,
              ),
              const Text(
                'Setting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'time',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [5, 15, 30].map((minutes) {
              final selected = _durationMinutes == minutes;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _durationMinutes = minutes),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFF4081)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFF4081)
                              : Colors.white38,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$minutes min',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Mic mode',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4081),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text(
              '10',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '5 vs 5 team layout',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LuckyBagTheme.sendGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: LuckyBagTheme.sendShadow,
              ),
              child: ElevatedButton(
                onPressed: _starting ? null : _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.primaryDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _starting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Start',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
