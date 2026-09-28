class InviteEarnConfig {
  const InviteEarnConfig._();

  static const String heroAsset = 'assets/invite/invite_earn_hero.webp';
  static const String title = 'TO GET COINS EARNINGS';
  static const String dateRangeLabel = '2026 · 6.1 – 7.30';
  static const String downloadUrl =
      'https://sklive-sklive-landing.sin.app.zuvodev.com';

  static DateTime get endsAt => DateTime(2026, 7, 30, 23, 59, 59);

  static const String weeklyBonusLabel = '5M+';
  static const String weeklyBonusCaption =
      'Max Weekly Bonus for Inviting Friends to Register';

  static const String firstRechargeLabel = '3%';
  static const String firstRechargeCaption = "Friend's First Recharge Bonus";

  static const String everyRechargeLabel = '1%';
  static const String everyRechargeCaption = 'Bonus on Every Friend Recharge';

  static const List<InviteMilestone> milestones = [
    InviteMilestone(coinsLabel: '500', invitesNeeded: 1, rewardCoins: 500),
    InviteMilestone(coinsLabel: '1000', invitesNeeded: 3, rewardCoins: 1000),
    InviteMilestone(coinsLabel: '3000', invitesNeeded: 5, rewardCoins: 3000),
    InviteMilestone(coinsLabel: '8000', invitesNeeded: 10, rewardCoins: 8000),
    InviteMilestone(coinsLabel: '20K', invitesNeeded: 20, rewardCoins: 20000),
    InviteMilestone(coinsLabel: '50K', invitesNeeded: 50, rewardCoins: 50000),
    InviteMilestone(
      coinsLabel: '100K',
      invitesNeeded: 100,
      rewardCoins: 100000,
    ),
    InviteMilestone(
      coinsLabel: '500K',
      invitesNeeded: 200,
      rewardCoins: 500000,
    ),
  ];

  static const int prizeChanceSlots = 5;
  static const int prizeChancesPerFriend = 2;
  static const int prizeChanceFriendCap = 10;

  static const List<String> rules = [
    'Share your invitation code (your Short ID) with friends.',
    'Friends enter your code on the profile setup screen when they join.',
    'You earn 100 coins when a friend registers with your code.',
    'Your friend also gets a 50-coin welcome bonus.',
    'Claim milestone rewards after enough successful invites.',
    'First 10 weekly invites unlock 2 lucky-wheel draws each.',
    'When a referred friend recharges, you earn 3% on their first recharge and 1% on later recharges.',
  ];

  static const List<InviteWheelSegment> wheelSegments = [
    InviteWheelSegment(label: '100-300', colorValue: 0xFFE8B923),
    InviteWheelSegment(label: '301-600', colorValue: 0xFF2E7D4F),
    InviteWheelSegment(label: '601-1K', colorValue: 0xFFC9A227),
    InviteWheelSegment(label: 'AGAIN', colorValue: 0xFF0F3D2A),
  ];
}

class InviteMilestone {
  const InviteMilestone({
    required this.coinsLabel,
    required this.invitesNeeded,
    required this.rewardCoins,
  });

  final String coinsLabel;
  final int invitesNeeded;
  final int rewardCoins;
}

class InviteWheelSegment {
  const InviteWheelSegment({required this.label, required this.colorValue});

  final String label;
  final int colorValue;
}
