import 'package:flutter/material.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_assets.dart';

class WeeklyRoomRewardRulesSheet extends StatelessWidget {
  const WeeklyRoomRewardRulesSheet({super.key, required this.rules});

  final List<String> rules;

  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required List<String> rules,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => WeeklyRoomRewardRulesSheet(rules: rules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width * 0.86;
    final displayRules = rules.isEmpty
        ? const [
            'Cycle Period: Every Sunday to the following Saturday (UTC+3).',
            'Corresponding rewards will be earned based on the Room Charm Value.',
            'The room owner is eligible for coin rewards.',
            'After each cycle ends, only the highest unlocked reward level can be claimed.',
            'Rewards must be claimed within 6 days; expired rewards will disappear.',
            'Claimed coins are credited immediately.',
            'Successfully received rewards are credited to your account.',
          ]
        : rules;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: w,
          height: (w * 1.05).clamp(
            280.0,
            MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  WeeklyRoomRewardAssets.rulesCard,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: w * 0.12,
                right: w * 0.12,
                top: w * 0.14,
                bottom: w * 0.10,
                child: Column(
                  children: [
                    const Text(
                      'Rules',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: displayRules.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return Text(
                            '${index + 1}. ${displayRules[index]}',
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
