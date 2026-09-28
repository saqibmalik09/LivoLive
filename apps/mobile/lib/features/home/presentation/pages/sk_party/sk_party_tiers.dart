class SkHostTier {
  const SkHostTier({
    required this.level,
    required this.charms,
    required this.coinReward,
    this.days = 7,
    this.hours = 14,
  });

  final int level;
  final int charms;
  final int coinReward;
  final int days;
  final int hours;

  Map<String, dynamic> toJson() => {
    'level': level,
    'charms': charms,
    'coin_reward': coinReward,
    'days': days,
    'hours': hours,
  };

  factory SkHostTier.fromJson(Map<String, dynamic> json) {
    return SkHostTier(
      level: (json['level'] as num?)?.toInt() ?? 1,
      charms: (json['charms'] as num?)?.toInt() ?? 0,
      coinReward:
          (json['coin_reward'] as num?)?.toInt() ??
          (json['coins'] as num?)?.toInt() ??
          0,
      days: (json['days'] as num?)?.toInt() ?? 7,
      hours: (json['hours'] as num?)?.toInt() ?? 14,
    );
  }
}

List<SkHostTier> defaultSkHostTiers() {
  const charms = <int>[
    500000,
    1000000,
    2000000,
    3500000,
    5000000,
    8000000,
    12000000,
    18000000,
    25000000,
    35000000,
    50000000,
    70000000,
    100000000,
    140000000,
    200000000,
    280000000,
    400000000,
    550000000,
    750000000,
    1000000000,
    1300000000,
    1700000000,
    2200000000,
    2600000000,
    3000000000,
  ];
  const coins = <int>[
    50000,
    100000,
    200000,
    350000,
    500000,
    800000,
    1200000,
    1800000,
    2500000,
    3500000,
    5000000,
    7000000,
    10000000,
    12000000,
    14000000,
    16000000,
    18000000,
    20000000,
    22000000,
    24000000,
    25500000,
    27000000,
    28000000,
    29000000,
    30000000,
  ];

  return List.generate(25, (i) {
    return SkHostTier(level: i + 1, charms: charms[i], coinReward: coins[i]);
  });
}

List<SkHostTier>? parseSkHostTiers(Map<String, dynamic> actionConfig) {
  final raw = actionConfig['reward_tiers'] ?? actionConfig['host_tiers'];
  if (raw is! List || raw.isEmpty) return null;
  final out = <SkHostTier>[];
  for (final item in raw) {
    if (item is Map) {
      out.add(SkHostTier.fromJson(Map<String, dynamic>.from(item)));
    }
  }
  return out.isEmpty ? null : out;
}

int skHostLevelFor({
  required List<SkHostTier> tiers,
  required int charms,
  required int workDays,
  required int workHours,
}) {
  var level = 0;
  for (final t in tiers) {
    final timeOk = workDays >= t.days && workHours >= t.hours;
    if (charms >= t.charms && timeOk) {
      level = t.level;
    } else {
      break;
    }
  }
  return level;
}
