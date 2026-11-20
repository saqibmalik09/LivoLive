import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_country_regions.dart';

class HomeRefCountrySheet extends StatefulWidget {
  const HomeRefCountrySheet({
    super.key,
    required this.onSelect,
    this.selectedCode,
  });

  final ValueChanged<Country> onSelect;

  final String? selectedCode;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Country> onSelect,
    String? selectedCode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) =>
          HomeRefCountrySheet(onSelect: onSelect, selectedCode: selectedCode),
    );
  }

  static const double designWidth = 750;

  static const double heightFraction = 805 / 1626;
  static const double radius = 40;
  static const double titleTop = 31;
  static const double titleLeft = 29;
  static const double titleSize = 37;
  static const double chipsTop = 111;
  static const double chipHeight = 50;
  static const double chipGap = 31;
  static const double chipText = 26;
  static const double gridTop = 187;
  static const double side = 24;
  static const double columnGap = 16;
  static const double cellHeight = 68;
  static const double rowGap = 24.5;
  static const double flagLeft = 27;
  static const double flagWidth = 63;
  static const double nameGap = 11;
  static const double nameSize = 26;

  static const Color titleColor = Color(0xFF001516);
  static const Color nameColor = Color(0xFF061C17);
  static const Color chipOn1 = Color(0xFF129583);
  static const Color chipOn2 = Color(0xFF2FA38C);
  static const Color chipOff = Color(0xFFC0E2D5);
  static const Color chipOffText = Color(0xFF2F9A88);
  static const Color cellTop = Color(0xFFDBFEE6);
  static const Color cellBottom = Color(0xFFE5FCEC);

  @override
  State<HomeRefCountrySheet> createState() => _HomeRefCountrySheetState();
}

class _HomeRefCountrySheetState extends State<HomeRefCountrySheet> {
  late HomeCountryRegion _region;
  final Map<String, Country> _byCode = {};
  final ScrollController _grid = ScrollController();
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    for (final c in CountryService().getAll()) {
      _byCode[c.countryCode.toUpperCase()] = c;
    }
    _region =
        HomeCountryRegions.regionOf(widget.selectedCode) ??
        HomeCountryRegion.middleEast;
  }

  @override
  void dispose() {
    _grid.dispose();
    _search.dispose();
    super.dispose();
  }

  String _label(HomeCountryRegion r) => switch (r) {
    HomeCountryRegion.middleEast => context.l10n.home_regionMiddleEast,
    HomeCountryRegion.asia => context.l10n.home_regionAsia,
    HomeCountryRegion.america => context.l10n.home_regionAmerica,
    HomeCountryRegion.europe => context.l10n.home_regionEurope,
    HomeCountryRegion.africa => context.l10n.home_regionAfrica,
  };

  String _name(Country c) {
    final t = c.getTranslatedName(context);
    return (t == null || t.isEmpty) ? c.name : t;
  }

  List<Country> _visible() {
    final q = _search.text.trim().toLowerCase();
    if (_searching && q.isNotEmpty) {
      return [
        for (final r in HomeCountryRegions.order)
          for (final code in HomeCountryRegions.codes[r]!)
            if (_byCode[code] case final c?)
              if (_name(c).toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q) ||
                  c.countryCode.toLowerCase() == q)
                c,
      ];
    }
    return [
      for (final code in HomeCountryRegions.codes[_region]!) ?_byCode[code],
    ];
  }

  void _pick(Country c) {
    Navigator.of(context).pop();
    widget.onSelect(c);
  }

  void _selectRegion(HomeCountryRegion r) {
    if (r == _region) return;
    setState(() => _region = r);
    if (_grid.hasClients) _grid.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final s = media.size.width / HomeRefCountrySheet.designWidth;
    final height = media.size.height * HomeRefCountrySheet.heightFraction;
    final countries = _visible();

    final title = _searching
        ? TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: 30 * s,
              color: HomeRefCountrySheet.titleColor,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: context.l10n.party_searchCountry,
              border: InputBorder.none,
            ),
          )
        : Text(
            context.l10n.home_selectCountry,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: HomeRefCountrySheet.titleSize * s,
              fontWeight: FontWeight.w500,
              color: HomeRefCountrySheet.titleColor,
              height: 1.2,
            ),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HomeRefCountrySheet.radius * s),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [
              0,
              24 * s / height,
              195 * s / height,
              (600 * s / height).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFF0B8E86),
              Color(0xFF22998E),
              Color(0xFFD0E9CD),
              Color(0xFFFFFFFE),
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: HomeRefCountrySheet.titleTop * s),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: HomeRefCountrySheet.titleLeft * s,
                  end: 12 * s,
                ),
                child: SizedBox(
                  height: 56 * s,
                  child: Row(
                    children: [
                      Expanded(child: title),
                      IconButton(
                        tooltip: context.l10n.party_searchCountry,
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _search.clear();
                          if (_grid.hasClients) _grid.jumpTo(0);
                        }),
                        icon: Icon(
                          _searching ? Icons.close_rounded : Icons.search,
                          color: HomeRefCountrySheet.titleColor,
                          size: 40 * s,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height:
                    (HomeRefCountrySheet.chipsTop -
                            HomeRefCountrySheet.titleTop) *
                        s -
                    56 * s,
              ),
              SizedBox(
                height: HomeRefCountrySheet.chipHeight * s,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: HomeRefCountrySheet.side * s,
                  ),
                  itemCount: HomeCountryRegions.order.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: HomeRefCountrySheet.chipGap * s),
                  itemBuilder: (context, i) {
                    final r = HomeCountryRegions.order[i];
                    final on = !_searching && r == _region;
                    return GestureDetector(
                      onTap: () {
                        if (_searching) {
                          setState(() {
                            _searching = false;
                            _search.clear();
                          });
                        }
                        _selectRegion(r);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 25 * s),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            HomeRefCountrySheet.chipHeight * s / 2,
                          ),
                          color: on ? null : HomeRefCountrySheet.chipOff,
                          gradient: on
                              ? const LinearGradient(
                                  colors: [
                                    HomeRefCountrySheet.chipOn1,
                                    HomeRefCountrySheet.chipOn2,
                                  ],
                                )
                              : null,
                        ),
                        child: Text(
                          _label(r),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: HomeRefCountrySheet.chipText * s,
                            fontWeight: FontWeight.w400,
                            color: on
                                ? Colors.white
                                : HomeRefCountrySheet.chipOffText,
                            height: 1.1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: _grid,
                  padding: EdgeInsets.fromLTRB(
                    HomeRefCountrySheet.side * s,
                    (HomeRefCountrySheet.gridTop -
                            HomeRefCountrySheet.chipsTop -
                            HomeRefCountrySheet.chipHeight) *
                        s,
                    HomeRefCountrySheet.side * s,
                    media.padding.bottom + 24 * s,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisExtent: HomeRefCountrySheet.cellHeight * s,
                    crossAxisSpacing: HomeRefCountrySheet.columnGap * s,
                    mainAxisSpacing: HomeRefCountrySheet.rowGap * s,
                  ),
                  itemCount: countries.length,
                  itemBuilder: (context, i) {
                    final c = countries[i];
                    return _CountryCell(
                      key: ValueKey('country-${c.countryCode}'),
                      flag: c.flagEmoji,
                      name: _name(c),
                      scale: s,
                      onTap: () => _pick(c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryCell extends StatelessWidget {
  const _CountryCell({
    super.key,
    required this.flag,
    required this.name,
    required this.scale,
    required this.onTap,
  });

  final String flag;
  final String name;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * s),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              HomeRefCountrySheet.cellTop,
              HomeRefCountrySheet.cellBottom,
            ],
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: HomeRefCountrySheet.flagLeft * s),
            SizedBox(
              width: HomeRefCountrySheet.flagWidth * s,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  flag,
                  style: TextStyle(
                    fontSize: HomeRefCountrySheet.flagWidth * s,
                    height: 1,
                  ),
                ),
              ),
            ),
            SizedBox(width: HomeRefCountrySheet.nameGap * s),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: HomeRefCountrySheet.nameSize * s,
                  fontWeight: FontWeight.w400,
                  color: HomeRefCountrySheet.nameColor,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(width: 8 * s),
          ],
        ),
      ),
    );
  }
}
