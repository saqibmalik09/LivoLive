import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/widgets/ref_pag_loop.dart';

class HomeRefBackground extends ConsumerWidget {
  const HomeRefBackground({
    super.key,
    this.tabKey = 'home',
    this.headerBottom = 320,
    this.fadeEnd = 480,
    this.dragonFadeFrom,
  });

  final String tabKey;

  final double headerBottom;
  final double fadeEnd;

  final double? dragonFadeFrom;

  Color _bgAt(double y) {
    final stops = [0.0, _mid, headerBottom, fadeEnd];
    const colors = [headerTealTop, headerTealMid, headerTealBottom, pageMint];
    if (y >= fadeEnd) return pageMint;
    for (var i = 0; i < 3; i++) {
      if (y <= stops[i + 1]) {
        final t = (y - stops[i]) / (stops[i + 1] - stops[i]);
        return Color.lerp(colors[i], colors[i + 1], t.clamp(0.0, 1.0))!;
      }
    }
    return pageMint;
  }

  static const String dragonAsset = 'assets/design/home/header_dragon.pag';

  static const Color pageMint = Color(0xFFEDFBF7);

  static const Color headerTealTop = Color(0xFF1B4B4C);
  static const Color headerTealMid = Color(0xFF329784);
  static const Color headerTealBottom = Color(0xFF4CA191);

  static const double dragonAspect = 642 / 1500;

  static const double _midStop = 180;

  double get _mid => headerBottom < _midStop ? headerBottom - 1 : _midStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHomeTab =
        ref.watch(bottomNavIndexProvider) == bottomNavIndexForKey(tabKey);
    final width = MediaQuery.sizeOf(context).width;
    final dragonHeight = width * dragonAspect;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: pageMint),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: width * fadeEnd / 750,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  headerTealTop,
                  headerTealMid,
                  headerTealBottom,
                  pageMint,
                ],
                stops: [0, _mid / fadeEnd, headerBottom / fadeEnd, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          width: width,
          height: dragonHeight,
          child: RefPagLoop(
            asset: dragonAsset,
            width: width,
            height: dragonHeight,
            active: isHomeTab,
          ),
        ),
        if (dragonFadeFrom != null)
          Positioned(
            top: width * dragonFadeFrom! / 750,
            left: 0,
            right: 0,
            height: dragonHeight - width * dragonFadeFrom! / 750,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _bgAt(dragonFadeFrom!).withValues(alpha: 0),
                      _bgAt(750 * dragonAspect),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
