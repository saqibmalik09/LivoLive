import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/widgets/promo_banner_carousel.dart';
import 'package:sk_live/features/task/presentation/pages/task_screen.dart';

class HomeTaskFloatButton extends StatefulWidget {
  const HomeTaskFloatButton({super.key});

  static const double size = 72;
  static const _prefKey = 'home_task_float_top_frac';

  @override
  State<HomeTaskFloatButton> createState() => _HomeTaskFloatButtonState();
}

class _HomeTaskFloatButtonState extends State<HomeTaskFloatButton> {
  double? _topFrac;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPref());
  }

  Future<void> _loadPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(HomeTaskFloatButton._prefKey);
      if (!mounted || v == null) return;
      setState(() => _topFrac = v.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _savePref(double frac) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(HomeTaskFloatButton._prefKey, frac.clamp(0.0, 1.0));
    } catch (_) {}
  }

  double _defaultTop(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return MediaQuery.paddingOf(context).top +
        kToolbarHeight +
        8 +
        4 +
        PromoBannerCarousel.heightForWidth(
          w - 16,
          ratio: PromoBannerCarousel.topAspectRatio,
          minH: 100,
          maxH: 200,
        ) +
        4;
  }

  ({double minTop, double maxTop, double range}) _dragBounds(
    BuildContext context,
  ) {
    final mq = MediaQuery.of(context);
    final minTop = mq.padding.top + kToolbarHeight + 4;
    final maxTop =
        mq.size.height -
        bottomNavTotalHeight(context) -
        HomeTaskFloatButton.size -
        8;
    final safeMax = maxTop < minTop ? minTop : maxTop;
    final range = (safeMax - minTop).clamp(1.0, double.infinity);
    return (minTop: minTop, maxTop: safeMax, range: range);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _dragBounds(context);
    final defaultTop = _defaultTop(context).clamp(bounds.minTop, bounds.maxTop);
    final top = _topFrac == null
        ? defaultTop
        : bounds.minTop + _topFrac! * bounds.range;

    return Positioned(
      right: 6,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: (details) {
          final next = (top + details.delta.dy).clamp(
            bounds.minTop,
            bounds.maxTop,
          );
          setState(() {
            _topFrac = ((next - bounds.minTop) / bounds.range).clamp(0.0, 1.0);
          });
        },
        onVerticalDragEnd: (_) {
          setState(() => _dragging = false);
          final frac = _topFrac;
          if (frac != null) unawaited(_savePref(frac));
        },
        onVerticalDragCancel: () => setState(() => _dragging = false),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskScreen()),
          );
        },
        child: AnimatedScale(
          scale: _dragging ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Image.asset(
            'assets/home/task_history_box.webp',
            width: HomeTaskFloatButton.size,
            height: HomeTaskFloatButton.size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
