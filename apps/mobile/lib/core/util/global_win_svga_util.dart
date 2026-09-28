class GlobalWinSvgaUtil {
  GlobalWinSvgaUtil._();

  static const giftAsset = 'assets/effects/global_win_gift.svga';
  static const gameAsset = 'assets/effects/global_win_game.svga';

  static String pickBannerAsset({required String variant}) {
    if (variant == 'game') {
      return gameAsset;
    }
    return giftAsset;
  }
}
