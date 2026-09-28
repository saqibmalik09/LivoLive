class BigGiftPattiUtil {
  BigGiftPattiUtil._();

  static const int thresholdCoins = 500000;
  static const String svgaAsset = 'assets/effects/entry_notice_vip8.svga';

  static bool meetsThreshold({required int priceCoins, required int quantity}) {
    if (priceCoins <= 0 || quantity <= 0) return false;
    return priceCoins * quantity >= thresholdCoins;
  }

  static int totalCoins({required int priceCoins, required int quantity}) =>
      priceCoins * quantity;
}
