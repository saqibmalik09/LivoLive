class RoomWinCardUtil {
  RoomWinCardUtil._();

  static String resolveMultiplierTier(int multiplier) {
    if (multiplier >= 450) return 'x500';
    if (multiplier >= 225) return 'x250';
    return 'x$multiplier';
  }

  static String pickBonusCardAsset({
    String? variant,
    String? tier,
    int multiplier = 1,
  }) {
    if (variant == 'lucky_pro' || tier == 'x500' || multiplier >= 450) {
      return 'assets/room/room_bonus_card_2.jpeg';
    }
    return 'assets/room/room_bonus_card_1.jpeg';
  }

  static int computeBonusMultiplier({
    required int rewardCoins,
    required int giftValue,
  }) {
    final safeGiftValue = giftValue <= 0 ? 1 : giftValue;
    return (rewardCoins / safeGiftValue).round().clamp(1, 999999);
  }
}
