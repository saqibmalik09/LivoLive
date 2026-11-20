import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/util/number_formatter.dart';

class MyProfileWalletCards extends StatelessWidget {
  const MyProfileWalletCards({
    super.key,
    required this.coins,
    required this.diamonds,
    required this.showDiamonds,
    required this.onTap,
  });

  final int coins;
  final int diamonds;
  final bool showDiamonds;
  final VoidCallback onTap;

  static const String coinCard = 'assets/design/me/card_coin.webp';
  static const String diamondCard = 'assets/design/me/card_diamond.webp';
  static const String coinIcon = 'assets/rewards/lucky-bag/coin-1.webp';
  static const String diamondIcon = 'assets/wallet/wallet_diamonds.webp';

  static const double height = 142;
  static const double coinLeft = 30;
  static const double coinWidth = 329;
  static const double diamondLeft = 393;
  static const double diamondWidth = 328;

  static const double textLeft = 142;
  static const double titleTop = 32;
  static const double valueTop = 78;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 750;
    return SizedBox(
      height: height * s,
      child: Stack(
        children: [
          Positioned(
            left: coinLeft * s,
            top: 0,
            width: coinWidth * s,
            height: height * s,
            child: _Card(
              background: coinCard,
              title: context.l10n.profile_coin,
              titleStyle: TextStyle(
                color: const Color(0xFF6A4C03),
                fontSize: 35 * s,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              value: NumberFormatter.format(coins),
              valueColor: const Color(0xFFA1760F),
              valueIcon: coinIcon,
              valueIconSize: 36,
              scale: s,
              onTap: onTap,
            ),
          ),
          Positioned(
            left: diamondLeft * s,
            top: 0,
            width: diamondWidth * s,
            height: height * s,
            child: _Card(
              background: diamondCard,
              title: context.l10n.wallet_diamond,
              titleStyle: TextStyle(
                color: const Color(0xFF0946A3),
                fontSize: 36 * s,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              value: showDiamonds ? NumberFormatter.format(diamonds) : null,
              valueColor: const Color(0xFF4C9BEA),
              valueIcon: diamondIcon,
              valueIconSize: 38,
              scale: s,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.background,
    required this.title,
    required this.titleStyle,
    required this.value,
    required this.valueColor,
    required this.valueIcon,
    required this.valueIconSize,
    required this.scale,
    required this.onTap,
  });

  final String background;
  final String title;
  final TextStyle titleStyle;

  final String? value;
  final Color valueColor;
  final String valueIcon;
  final double valueIconSize;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final v = value;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(background, fit: BoxFit.fill, gaplessPlayback: true),
          Positioned(
            left: MyProfileWalletCards.textLeft * s,
            right: 12 * s,
            top: MyProfileWalletCards.titleTop * s,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(title, maxLines: 1, style: titleStyle),
            ),
          ),
          if (v != null)
            Positioned(
              left: MyProfileWalletCards.textLeft * s,
              right: 12 * s,
              top: MyProfileWalletCards.valueTop * s,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 32 * s,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: 8 * s),
                  Image.asset(
                    valueIcon,
                    width: valueIconSize * s,
                    height: valueIconSize * s,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
