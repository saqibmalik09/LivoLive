import 'package:sk_live/core/models/global_win_announcement.dart';

class GlobalWinSvgaUtil {
  GlobalWinSvgaUtil._();

  static const giftAsset = 'assets/effects/global_win_gift.svga';
  static const gameAsset = 'assets/effects/global_win_game.svga';

  static const luckyX100Asset = 'assets/effects/lucky_banner_x100.svga';
  static const luckyX250Asset = 'assets/effects/lucky_banner_x250.svga';
  static const luckyX500Asset = 'assets/effects/lucky_banner_x500.svga';
  static const luckyX1000Asset = 'assets/effects/lucky_banner_x1000.svga';
  static const luckyTierAssets = <String>[
    luckyX100Asset,
    luckyX250Asset,
    luckyX500Asset,
    luckyX1000Asset,
  ];

  static const gameBannerImage = 'assets/effects/game_win_banner.png';

  static const luckyMinMultiplier = 100;
  static const gameMinCoins = 1000000;

  static bool isLucky(String variant) =>
      variant == 'lucky' || variant == 'lucky_pro';

  static bool showsTopBanner(GlobalWinAnnouncement win) {
    if (isLucky(win.variant)) return win.bonusMultiplier >= luckyMinMultiplier;
    if (win.variant == 'game') return win.rewardCoins >= gameMinCoins;
    return true;
  }

  static String? luckyTierAsset(int multiplier) {
    if (multiplier >= 1000) return luckyX1000Asset;
    if (multiplier >= 500) return luckyX500Asset;
    if (multiplier >= 250) return luckyX250Asset;
    if (multiplier >= luckyMinMultiplier) return luckyX100Asset;
    return null;
  }

  static String pickBannerAsset({
    required String variant,
    int bonusMultiplier = 1,
  }) {
    if (variant == 'game') {
      return gameAsset;
    }
    if (isLucky(variant)) {
      return luckyTierAsset(bonusMultiplier) ?? giftAsset;
    }
    return giftAsset;
  }
}
