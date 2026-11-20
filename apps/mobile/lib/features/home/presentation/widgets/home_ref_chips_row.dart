import 'package:flutter/material.dart';

class HomeRefChipsRow extends StatelessWidget {
  const HomeRefChipsRow({
    super.key,
    required this.popularLabel,
    required this.countries,
    required this.onCountryTap,
    required this.onFilterTap,
  });

  final String popularLabel;

  final List<({String code, String label})> countries;
  final ValueChanged<String> onCountryTap;
  final VoidCallback onFilterTap;

  static const String fireAsset = 'assets/design/home/icon_fire_popular.webp';
  static const String filterAsset = 'assets/design/home/btn_filter_gold.webp';

  static const double _designWidth = 750;
  static const double _chipHeight = 51;
  static const double _sideMargin = 24;
  static const double _gap = 25;
  static const double _textSize = 24;
  static const double _fireSize = 36;
  static const double _filterCanvas = 62;
  static const double _filterRight = 15;
  static const double _topGap = 7;
  static const double _bottomGap = 23;

  static double rowHeight(double s) =>
      (_topGap + _filterCanvas + _bottomGap) * s;

  static double chipTop(double s) =>
      (_topGap + (_filterCanvas - _chipHeight) / 2) * s;

  static const Color _goldTop = Color(0xFFF1FCD8);
  static const Color _goldMid = Color(0xFFF8DA8D);
  static const Color _goldBottom = Color(0xFFF5C56C);
  static const Color _goldBorder = Color(0xFFE5C057);
  static const Color _beige = Color(0xFFF1ECE8);
  static const Color _textSelected = Color(0xFF5A3A0A);
  static const Color _textUnselected = Color(0xFF7E6951);

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / _designWidth;
    final chipH = _chipHeight * s;
    final textStyle = TextStyle(
      fontSize: _textSize * s,
      fontWeight: FontWeight.w500,
      height: 1.1,
    );

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback? onTap,
      Widget? leading,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: chipH,
          padding: EdgeInsets.symmetric(horizontal: 26 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(chipH / 2),
            color: selected ? null : _beige,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_goldTop, _goldMid, _goldBottom],
                  )
                : null,
            border: selected
                ? Border.all(color: _goldBorder, width: 2 * s)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, SizedBox(width: 8 * s)],
              Text(
                label,
                maxLines: 1,
                style: textStyle.copyWith(
                  color: selected ? _textSelected : _textUnselected,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final popular = chip(
      label: popularLabel,
      selected: true,
      onTap: null,
      leading: Image.asset(
        fireAsset,
        width: _fireSize * s,
        height: _fireSize * s,
        filterQuality: FilterQuality.medium,
      ),
    );
    final labelPainter = TextPainter(
      text: TextSpan(
        text: popularLabel,
        style: DefaultTextStyle.of(
          context,
        ).style.merge(textStyle.copyWith(color: _textSelected)),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final popularWidth =
        (26 * 2 + _fireSize + 8 + 2 * 2) * s +
        labelPainter.width.ceilToDouble();
    labelPainter.dispose();

    return Padding(
      padding: EdgeInsets.only(top: _topGap * s, bottom: _bottomGap * s),
      child: SizedBox(
        height: _filterCanvas * s,
        child: Row(
          children: [
            SizedBox(width: _sideMargin * s),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  PositionedDirectional(
                    start: popularWidth / 2,
                    top: 0,
                    bottom: 0,
                    end: 0,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsetsDirectional.only(
                        start: popularWidth / 2 + _gap * s,
                      ),
                      children: [
                        for (final c in countries) ...[
                          Center(
                            child: chip(
                              label: c.label,
                              selected: false,
                              onTap: () => onCountryTap(c.code),
                            ),
                          ),
                          SizedBox(width: _gap * s),
                        ],
                      ],
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IntrinsicWidth(child: popular),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onFilterTap,
              child: Image.asset(
                filterAsset,
                width: _filterCanvas * s,
                height: _filterCanvas * s,
                filterQuality: FilterQuality.medium,
              ),
            ),
            SizedBox(width: _filterRight * s),
          ],
        ),
      ),
    );
  }
}
