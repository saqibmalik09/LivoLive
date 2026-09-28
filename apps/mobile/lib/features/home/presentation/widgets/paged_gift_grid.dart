import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/providers/shop_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';

class SmoothPageScrollPhysics extends PageScrollPhysics {
  const SmoothPageScrollPhysics({super.parent});

  static const double _snapThreshold = 0.25;

  @override
  SmoothPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 12;

  @override
  double get dragStartDistanceMotionThreshold => 1.0;

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.22, stiffness: 140, damping: 18);

  int _targetPage(PageMetrics metrics, double velocity) {
    final page = metrics.page!;
    final delta = page - page.roundToDouble();

    if (velocity.abs() >= minFlingVelocity) {
      return velocity > 0 ? page.floor() + 1 : page.ceil() - 1;
    }

    if (delta > _snapThreshold) return page.ceil();
    if (delta < -_snapThreshold) return page.floor();
    return page.round();
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final metrics = position as PageMetrics;
    final maxPage = metrics.maxScrollExtent ~/ metrics.viewportDimension;
    final targetPage = _targetPage(metrics, velocity).clamp(0, maxPage);
    final targetPixels = (targetPage * metrics.viewportDimension).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class _GiftPage {
  final String categoryId;
  final int localPageIndex;
  final List<ShopItem> gifts;

  const _GiftPage({
    required this.categoryId,
    required this.localPageIndex,
    required this.gifts,
  });
}

class PagedGiftGrid extends StatefulWidget {
  final List<String> categoryIds;
  final Map<String, List<ShopItem>> giftsByCategory;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategoryChanged;
  final String? selectedGiftId;
  final ValueChanged<ShopItem> onGiftSelected;
  final Map<String, Set<EventGiftMarkerKind>> eventMarkers;

  const PagedGiftGrid({
    super.key,
    required this.categoryIds,
    required this.giftsByCategory,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.selectedGiftId,
    required this.onGiftSelected,
    this.eventMarkers = const {},
  });

  static const int crossAxisCount = 4;
  static const int rowsPerPage = 2;
  static const int giftsPerPage = crossAxisCount * rowsPerPage;
  static const double gridSpacing = 12.0;
  static const double hPad = 16.0;
  static const double cellAspectRatio = 0.88;

  static double gridHeightForWidth(double width) {
    final gridWidth = width - hPad * 2;
    final cellWidth =
        (gridWidth - gridSpacing * (crossAxisCount - 1)) / crossAxisCount;
    final cellHeight = cellWidth / cellAspectRatio;
    return cellHeight * rowsPerPage + gridSpacing * (rowsPerPage - 1);
  }

  static const double dotsRowHeight = 10.0;

  static double sheetGiftAreaHeight(double width) {
    return gridHeightForWidth(width) + dotsRowHeight;
  }

  @override
  State<PagedGiftGrid> createState() => _PagedGiftGridState();
}

class _PagedGiftGridState extends State<PagedGiftGrid> {
  late final PageController _pageController;
  int _currentGlobalPage = 0;
  String? _swipeNotifiedCategoryId;

  List<_GiftPage> get _pages {
    final pages = <_GiftPage>[];
    for (final catId in widget.categoryIds) {
      final gifts = widget.giftsByCategory[catId] ?? [];
      if (gifts.isEmpty) continue;
      final pageCount = (gifts.length / PagedGiftGrid.giftsPerPage).ceil();
      for (var i = 0; i < pageCount; i++) {
        final start = i * PagedGiftGrid.giftsPerPage;
        final end = (start + PagedGiftGrid.giftsPerPage).clamp(0, gifts.length);
        pages.add(
          _GiftPage(
            categoryId: catId,
            localPageIndex: i,
            gifts: gifts.sublist(start, end),
          ),
        );
      }
    }
    return pages;
  }

  String? get _activeCategoryId {
    final pages = _pages;
    if (pages.isEmpty) return widget.selectedCategoryId;
    final idx = _currentGlobalPage.clamp(0, pages.length - 1);
    return pages[idx].categoryId;
  }

  int get _localPageInCategory {
    final pages = _pages;
    if (pages.isEmpty) return 0;
    final idx = _currentGlobalPage.clamp(0, pages.length - 1);
    return pages[idx].localPageIndex;
  }

  int _pageCountForCategory(String categoryId) {
    final gifts = widget.giftsByCategory[categoryId] ?? [];
    if (gifts.isEmpty) return 0;
    return (gifts.length / PagedGiftGrid.giftsPerPage).ceil();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedCategoryId != null) {
        _jumpToCategory(widget.selectedCategoryId!, animate: false);
      }
    });
  }

  @override
  void didUpdateWidget(PagedGiftGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategoryId != null &&
        widget.selectedCategoryId != oldWidget.selectedCategoryId &&
        widget.selectedCategoryId != _swipeNotifiedCategoryId) {
      _jumpToCategory(widget.selectedCategoryId!);
    }
    _swipeNotifiedCategoryId = null;

    final pages = _pages;
    if (pages.isNotEmpty && _currentGlobalPage >= pages.length) {
      _currentGlobalPage = pages.length - 1;
      _pageController.jumpToPage(_currentGlobalPage);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToCategory(String categoryId, {bool animate = true}) {
    final index = _pages.indexWhere(
      (p) => p.categoryId == categoryId && p.localPageIndex == 0,
    );
    if (index < 0) return;
    if (animate) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
      setState(() => _currentGlobalPage = index);
    }
  }

  void _onGlobalPageChanged(int index) {
    final pages = _pages;
    if (index < 0 || index >= pages.length) return;
    final page = pages[index];
    setState(() => _currentGlobalPage = index);

    if (page.categoryId != widget.selectedCategoryId) {
      _swipeNotifiedCategoryId = page.categoryId;
      widget.onCategoryChanged(page.categoryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages.isEmpty) {
      return const Center(
        child: Text(
          'No gifts available',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    final activeCat = _activeCategoryId;
    final categoryPageCount = activeCat != null
        ? _pageCountForCategory(activeCat)
        : 0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final gridHeight = PagedGiftGrid.gridHeightForWidth(screenWidth);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: gridHeight,
          child: PageView.builder(
            controller: _pageController,
            physics: const SmoothPageScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            onPageChanged: _onGlobalPageChanged,
            itemCount: pages.length,
            itemBuilder: (context, globalIndex) {
              return _buildGridPage(pages[globalIndex].gifts, screenWidth);
            },
          ),
        ),
        if (categoryPageCount > 1) _buildPageDots(categoryPageCount),
      ],
    );
  }

  Widget _buildGridPage(List<ShopItem> pageGifts, double width) {
    const spacing = PagedGiftGrid.gridSpacing;
    final gridHeight = PagedGiftGrid.gridHeightForWidth(width);

    return SizedBox(
      height: gridHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PagedGiftGrid.hPad),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: PagedGiftGrid.crossAxisCount,
            childAspectRatio: PagedGiftGrid.cellAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: pageGifts.length,
          itemBuilder: (context, index) {
            return _buildGiftTile(pageGifts[index]);
          },
        ),
      ),
    );
  }

  Widget _buildPageDots(int count) {
    final activeDot = _localPageInCategory;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == activeDot;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? Colors.amber : Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGiftTile(ShopItem gift) {
    final isSelected = widget.selectedGiftId == gift.id;
    final markers =
        widget.eventMarkers[gift.id] ?? const <EventGiftMarkerKind>{};

    return GestureDetector(
      onTap: () => widget.onGiftSelected(gift),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white12,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(1, 2, 1, 0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    gift.imageUrl != null
                        ? AppNetworkImage(
                            imageUrl: gift.imageUrl!,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: double.infinity,
                            transformWidth: 256,
                            transformHeight: 256,
                          )
                        : const Icon(
                            Icons.card_giftcard,
                            color: Colors.amber,
                            size: 52,
                          ),
                    if (markers.isNotEmpty)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _EventGiftMarkerBadges(markers: markers),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(1, 0, 1, 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gift.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.coin, color: Colors.amber, size: 7),
                      const SizedBox(width: 1),
                      Text(
                        NumberFormatter.format(gift.priceCoins),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventGiftMarkerBadges extends StatelessWidget {
  const _EventGiftMarkerBadges({required this.markers});

  final Set<EventGiftMarkerKind> markers;

  @override
  Widget build(BuildContext context) {
    final ordered = <EventGiftMarkerKind>[
      if (markers.contains(EventGiftMarkerKind.cp)) EventGiftMarkerKind.cp,
      if (markers.contains(EventGiftMarkerKind.weeklyStar))
        EventGiftMarkerKind.weeklyStar,
      if (markers.contains(EventGiftMarkerKind.webview))
        EventGiftMarkerKind.webview,
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final kind in ordered)
          Padding(
            padding: const EdgeInsets.only(left: 1),
            child: eventGiftMarkerBadge(kind),
          ),
      ],
    );
  }
}

({IconData icon, Color color, String label}) eventGiftMarkerStyle(
  EventGiftMarkerKind kind,
) {
  return switch (kind) {
    EventGiftMarkerKind.cp => (
      icon: Icons.favorite,
      color: const Color(0xFFFF69B4),
      label: 'CP',
    ),
    EventGiftMarkerKind.weeklyStar => (
      icon: Icons.star,
      color: const Color(0xFFFFD54F),
      label: 'Weekly Star',
    ),
    EventGiftMarkerKind.webview => (
      icon: Icons.flag,
      color: const Color(0xFF43A047),
      label: 'Event',
    ),
  };
}

Widget eventGiftMarkerBadge(EventGiftMarkerKind kind) {
  final style = eventGiftMarkerStyle(kind);
  return Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      shape: BoxShape.circle,
      border: Border.all(color: style.color, width: 0.8),
    ),
    child: Icon(style.icon, size: 9, color: style.color),
  );
}

class EventGiftMarkerLegend extends StatelessWidget {
  const EventGiftMarkerLegend({super.key, required this.kinds});

  final Set<EventGiftMarkerKind> kinds;

  @override
  Widget build(BuildContext context) {
    final ordered = <EventGiftMarkerKind>[
      if (kinds.contains(EventGiftMarkerKind.cp)) EventGiftMarkerKind.cp,
      if (kinds.contains(EventGiftMarkerKind.weeklyStar))
        EventGiftMarkerKind.weeklyStar,
      if (kinds.contains(EventGiftMarkerKind.webview))
        EventGiftMarkerKind.webview,
    ];
    if (ordered.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Icon(
              eventGiftMarkerStyle(ordered[i]).icon,
              size: 11,
              color: eventGiftMarkerStyle(ordered[i]).color,
            ),
            const SizedBox(width: 3),
            Text(
              eventGiftMarkerStyle(ordered[i]).label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
