import 'package:flutter/material.dart';
import 'package:sk_live/features/home/presentation/widgets/ref_squiggle_tab_indicator.dart';

class HomeRefTabBar extends StatelessWidget {
  const HomeRefTabBar({
    super.key,
    required this.controller,
    required this.labels,
  });

  final TabController controller;
  final List<String> labels;

  static const double designWidth = 750;

  static const double fontSize = 36;
  static const Color unselectedColor = Color(0xFFB9DED3);

  static const double labelGap = 23;
  static const double startInset = 28 - labelGap / 2;

  static const double rowDrop = 14;

  static const double squiggleWidth = 59;
  static const double squiggleHeight = 15;
  static const double squiggleBelowCenter = 25;

  static const List<Shadow> shadows = [
    Shadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static double scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  static Widget rowIcon(BuildContext context, Widget icon) =>
      Transform.translate(
        offset: Offset(0, rowDrop * scaleOf(context)),
        child: icon,
      );

  @override
  Widget build(BuildContext context) {
    final s = scaleOf(context);
    return Transform.translate(
      offset: Offset(0, rowDrop * s),
      child: Container(
        margin: EdgeInsetsDirectional.only(start: startInset * s, end: 4),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicator: RefSquiggleTabIndicator(
            width: squiggleWidth * s,
            height: squiggleHeight * s,
            belowCenter: squiggleBelowCenter * s,
          ),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: unselectedColor,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.symmetric(horizontal: labelGap / 2 * s),
          labelStyle: TextStyle(
            fontSize: fontSize * s,
            fontWeight: FontWeight.w700,
            shadows: shadows,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: fontSize * s,
            fontWeight: FontWeight.w400,
            shadows: shadows,
          ),
          tabs: [for (final label in labels) Tab(text: label)],
        ),
      ),
    );
  }
}
