abstract final class RoomRewardAssets {
  static const String _base = 'assets/rewards';

  static const String giftboxBg = '$_base/giftbox-bg.webp';
  static const String recordButton = '$_base/record-button.webp';
  static const String signinRewardSvga = '$_base/beaver_signin_reward.svga';

  static String shelfBoxSvga(int level) {
    final lv = level.clamp(1, 5);
    return '$_base/beaver_sign_box_level_$lv.svga';
  }

  static String apertureBoxSvga(int level) {
    final lv = level.clamp(1, 5);
    return '$_base/beaver_sign_box_aperture_level_$lv.svga';
  }

  static String boxPngForLevel(int level) {
    return switch (level.clamp(1, 5)) {
      1 => '$_base/lv1-box.webp',
      2 => '$_base/lv2-box.webp',
      3 => '$_base/lv3-box.webp',
      4 => '$_base/lv4-box.webp',
      _ => '$_base/lv5-box.webp',
    };
  }

  @Deprecated('Use shelfBoxSvga / apertureBoxSvga')
  static String boxForLevel(int level) => boxPngForLevel(level);
}
