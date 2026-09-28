import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskWheelSpin {
  const TaskWheelSpin({
    required this.id,
    required this.rewardLabel,
    required this.rewardCoins,
    required this.createdAt,
  });

  final String id;
  final String rewardLabel;
  final int rewardCoins;
  final DateTime createdAt;

  factory TaskWheelSpin.fromJson(Map<String, dynamic> json) {
    return TaskWheelSpin(
      id: json['id']?.toString() ?? '',
      rewardLabel: json['reward_label']?.toString() ?? '',
      rewardCoins: (json['reward_coins'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class TaskWheelTier {
  const TaskWheelTier({
    required this.label,
    required this.minCoins,
    required this.maxCoins,
    required this.weightPercent,
  });

  final String label;
  final int minCoins;
  final int maxCoins;
  final double weightPercent;

  factory TaskWheelTier.fromJson(Map<String, dynamic> json) {
    return TaskWheelTier(
      label:
          json['label']?.toString() ??
          '${json['min_coins'] ?? 0}-${json['max_coins'] ?? 0}',
      minCoins: (json['min_coins'] as num?)?.toInt() ?? 0,
      maxCoins: (json['max_coins'] as num?)?.toInt() ?? 0,
      weightPercent: (json['weight_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TaskCenterSummary {
  const TaskCenterSummary({
    required this.streakDay,
    required this.consecutiveDays,
    required this.checkedToday,
    required this.wheelDraws,
    required this.dayRewards,
    required this.spins,
    required this.wheelTiers,
  });

  final int streakDay;
  final int consecutiveDays;
  final bool checkedToday;
  final int wheelDraws;
  final List<int> dayRewards;
  final List<TaskWheelSpin> spins;
  final List<TaskWheelTier> wheelTiers;

  static const empty = TaskCenterSummary(
    streakDay: 0,
    consecutiveDays: 0,
    checkedToday: false,
    wheelDraws: 0,
    dayRewards: [1000, 1500, 3000, 2000, 5000, 2500, 7000],
    spins: [],
    wheelTiers: [],
  );

  factory TaskCenterSummary.fromJson(Map<String, dynamic> json) {
    final rewards = <int>[];
    final rawRewards = json['day_rewards'];
    if (rawRewards is List) {
      for (final e in rawRewards) {
        rewards.add((e as num?)?.toInt() ?? 0);
      }
    }
    final spins = <TaskWheelSpin>[];
    final rawSpins = json['spins'];
    if (rawSpins is List) {
      for (final e in rawSpins) {
        if (e is Map) {
          spins.add(TaskWheelSpin.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final tiers = <TaskWheelTier>[];
    final rawTiers = json['wheel_tiers'];
    if (rawTiers is List) {
      for (final e in rawTiers) {
        if (e is Map) {
          tiers.add(TaskWheelTier.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return TaskCenterSummary(
      streakDay: (json['streak_day'] as num?)?.toInt() ?? 0,
      consecutiveDays: (json['consecutive_days'] as num?)?.toInt() ?? 0,
      checkedToday: json['checked_today'] == true,
      wheelDraws: (json['wheel_draws'] as num?)?.toInt() ?? 0,
      dayRewards: rewards.isEmpty ? empty.dayRewards : rewards,
      spins: spins,
      wheelTiers: tiers,
    );
  }
}

final taskCenterSummaryProvider = FutureProvider.autoDispose<TaskCenterSummary>(
  (ref) async {
    final res = await Supabase.instance.client.rpc('get_task_center_summary');
    if (res is! Map) return TaskCenterSummary.empty;
    final map = Map<String, dynamic>.from(res);
    if (map['success'] != true) return TaskCenterSummary.empty;
    return TaskCenterSummary.fromJson(map);
  },
);

Future<Map<String, dynamic>> taskDailyCheckin() async {
  final res = await Supabase.instance.client.rpc('task_daily_checkin');
  if (res is Map) return Map<String, dynamic>.from(res);
  return {'success': false, 'message': 'Unexpected response'};
}

Future<Map<String, dynamic>> spinTaskWheel() async {
  final res = await Supabase.instance.client.rpc('spin_task_wheel');
  if (res is Map) return Map<String, dynamic>.from(res);
  return {'success': false, 'message': 'Unexpected response'};
}

class TaskWheelSegment {
  const TaskWheelSegment({required this.label, required this.colorValue});
  final String label;
  final int colorValue;
}

const _kWheelColors = <int>[
  0xFF6B3FA0,
  0xFFC9A227,
  0xFF4A2C7A,
  0xFFE8B923,
  0xFF7B4BB8,
  0xFFD4AF37,
  0xFFE91E8C,
  0xFFF0D060,
];

const kTaskWheelSegments = <TaskWheelSegment>[
  TaskWheelSegment(label: '100-300', colorValue: 0xFF6B3FA0),
  TaskWheelSegment(label: '301-600', colorValue: 0xFFC9A227),
  TaskWheelSegment(label: '601-1K', colorValue: 0xFF4A2C7A),
];

List<TaskWheelSegment> taskWheelSegmentsFromTiers(List<TaskWheelTier> tiers) {
  if (tiers.isEmpty) return kTaskWheelSegments;
  return [
    for (var i = 0; i < tiers.length; i++)
      TaskWheelSegment(
        label: tiers[i].label,
        colorValue: _kWheelColors[i % _kWheelColors.length],
      ),
  ];
}
