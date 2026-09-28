import 'package:flutter/material.dart';

class RoomToolbarButton extends StatelessWidget {
  const RoomToolbarButton({
    super.key,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.assetPath,
    this.style = RoomToolbarButtonStyle.circle,
    this.iconColor = const Color(0xFFF5F0E6),
    this.size = 34,
    this.badgeCount,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final String? assetPath;
  final RoomToolbarButtonStyle style;
  final Color iconColor;
  final double size;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: switch (style) {
        RoomToolbarButtonStyle.gift => _GiftButton(
          assetPath: assetPath!,
          size: size,
        ),
        RoomToolbarButtonStyle.game => _GameButton(
          assetPath: assetPath!,
          size: size,
        ),
        RoomToolbarButtonStyle.circle ||
        RoomToolbarButtonStyle.badge => _CircleButton(
          icon: icon,
          assetPath: assetPath,
          iconColor: iconColor,
          size: size,
          badgeCount: style == RoomToolbarButtonStyle.badge ? badgeCount : null,
        ),
      },
    );
  }
}

enum RoomToolbarButtonStyle { circle, gift, game, badge }

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.iconColor,
    required this.size,
    this.icon,
    this.assetPath,
    this.badgeCount,
  });

  final IconData? icon;
  final String? assetPath;
  final Color iconColor;
  final double size;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final content = assetPath != null
        ? Image.asset(
            assetPath!,
            width: size * 0.52,
            height: size * 0.52,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          )
        : Icon(icon, color: iconColor, size: size * 0.48);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.black.withValues(alpha: 0.42),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(child: content),
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                badgeCount! > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.assetPath, required this.size});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final giftSize = size + 8;
    return Container(
      width: giftSize,
      height: giftSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(assetPath, fit: BoxFit.contain, gaplessPlayback: true),
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({required this.assetPath, required this.size});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }
}
