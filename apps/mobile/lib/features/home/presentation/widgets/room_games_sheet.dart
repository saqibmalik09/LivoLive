import 'package:flutter/material.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';

class RoomGamesSheet extends StatelessWidget {
  const RoomGamesSheet({
    super.key,
    required this.games,
    required this.onGameTap,
    this.recentGames = const [],
  });

  final List<Map<String, dynamic>> games;
  final List<Map<String, dynamic>> recentGames;
  final void Function(Map<String, dynamic> game) onGameTap;

  static const _crossAxisCount = 4;
  static const _mainAxisSpacing = 14.0;
  static const _crossAxisSpacing = 12.0;
  static const _childAspectRatio = 0.78;
  static const _visibleRows = 4;
  static const _sheetBg = Color(0xFF1A1A2E);

  List<_GameSection> _sections() {
    final byKey = <String, _GameSection>{};
    for (final g in games) {
      final catId = (g['category_id'] ?? '').toString();
      final catName = (g['category_name'] ?? '').toString().trim();
      final key = catId.isNotEmpty
          ? catId
          : (catName.isNotEmpty ? catName : '__more__');
      final title = catName.isNotEmpty ? catName : 'More Games';
      final sort = _asInt(g['category_sort']) ?? 999;
      final section = byKey.putIfAbsent(
        key,
        () => _GameSection(title: title, sortOrder: sort, games: []),
      );
      section.games.add(g);
    }
    final list = byKey.values.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.title.compareTo(b.title);
      });
    for (final s in list) {
      s.games.sort((a, b) {
        final ao = _asInt(a['sort_order']) ?? 0;
        final bo = _asInt(b['sort_order']) ?? 0;
        return bo.compareTo(ao);
      });
    }
    if (recentGames.isNotEmpty) {
      list.insert(
        0,
        _GameSection(
          title: 'Recent',
          sortOrder: -1,
          games: recentGames.take(4).toList(),
        ),
      );
    }
    return list;
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final gridWidth = width - 40;
    final cellW =
        (gridWidth - _crossAxisSpacing * (_crossAxisCount - 1)) /
        _crossAxisCount;
    final rowH = cellW / _childAspectRatio;
    final fourRowsH =
        _visibleRows * rowH + (_visibleRows - 1) * _mainAxisSpacing;
    const headerH = 108.0;
    final maxSheetH = headerH + fourRowsH + 16 + bottom;

    final sections = _sections();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetH),
        child: Container(
          decoration: BoxDecoration(
            color: _sheetBg.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white10),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 8 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Games',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a game to play',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: games.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.yellowAccent,
                            strokeWidth: 2.4,
                          ),
                        )
                      : _DragDownToDismiss(
                          child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: sections.length,
                          itemBuilder: (context, sIndex) {
                            final section = sections[sIndex];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: sIndex == sections.length - 1 ? 4 : 18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.title,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: section.games.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: _crossAxisCount,
                                          mainAxisSpacing: _mainAxisSpacing,
                                          crossAxisSpacing: _crossAxisSpacing,
                                          childAspectRatio: _childAspectRatio,
                                        ),
                                    itemBuilder: (context, index) {
                                      final game = section.games[index];
                                      final name =
                                          (game['display_name'] ??
                                                  game['name'] ??
                                                  'Game')
                                              .toString();
                                      final icon =
                                          (game['icon_url'] ??
                                                  'assets/games/game_logo.webp')
                                              .toString();
                                      return _GameTile(
                                        name: name,
                                        iconUrlOrAsset: icon,
                                        onTap: () => onGameTap(game),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets a downward drag on the games list close the sheet.
///
/// `showModalBottomSheet` has `enableDrag: true`, but the list inside wins the
/// vertical drag in the gesture arena, so swiping down only scrolled and the
/// user had to tap the barrier to close. Once the list is at its top, further
/// downward pull is overscroll, and that is what dismisses here.
class _DragDownToDismiss extends StatefulWidget {
  const _DragDownToDismiss({required this.child});

  final Widget child;

  @override
  State<_DragDownToDismiss> createState() => _DragDownToDismissState();
}

class _DragDownToDismissState extends State<_DragDownToDismiss> {
  static const double _dismissAfter = 90;
  double _pulled = 0;
  bool _popped = false;

  void _pull(double pixels) {
    if (_popped || pixels <= 0) return;
    _pulled += pixels;
    if (_pulled < _dismissAfter) return;
    _popped = true;
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification) {
          // Clamping physics (Android) reports the pull here; a negative
          // overscroll is past the top edge.
          if (notification.dragDetails != null) _pull(-notification.overscroll);
        } else if (notification is ScrollUpdateNotification) {
          // Bouncing physics (iOS) scrolls out of range instead of reporting
          // overscroll, so measure how far past the top the list sits.
          if (notification.dragDetails != null) {
            final metrics = notification.metrics;
            final past = metrics.minScrollExtent - metrics.pixels;
            if (past >= _dismissAfter) _pull(past);
          }
        } else if (notification is ScrollStartNotification ||
            notification is ScrollEndNotification) {
          _pulled = 0;
        }
        return false;
      },
      child: widget.child,
    );
  }
}

class _GameSection {
  _GameSection({
    required this.title,
    required this.sortOrder,
    required this.games,
  });

  final String title;
  final int sortOrder;
  final List<Map<String, dynamic>> games;
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.name,
    required this.iconUrlOrAsset,
    required this.onTap,
  });

  final String name;
  final String iconUrlOrAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          const nameH = 16.0;
          const gap = 8.0;
          final iconSide = (constraints.maxHeight - nameH - gap).clamp(
            48.0,
            side,
          );

          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: iconSide,
                height: iconSide,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildIcon(),
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: nameH,
                width: double.infinity,
                child: _SlowMarqueeText(
                  text: name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIcon() {
    if (iconUrlOrAsset.startsWith('http')) {
      return AppNetworkImage(
        imageUrl: iconUrlOrAsset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,

        enableTransform: false,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.sports_esports_rounded,
          color: Colors.white70,
          size: 32,
        ),
      );
    }
    return Image.asset(
      iconUrlOrAsset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.sports_esports_rounded,
        color: Colors.white70,
        size: 32,
      ),
    );
  }
}

class _SlowMarqueeText extends StatefulWidget {
  const _SlowMarqueeText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_SlowMarqueeText> createState() => _SlowMarqueeTextState();
}

class _SlowMarqueeTextState extends State<_SlowMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _boxWidth = 0;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _SlowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    _boxWidth = box.size.width;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = painter.width;

    final overflow = _textWidth - _boxWidth;
    _needsScroll = overflow > 2;
    if (!_needsScroll) {
      _controller.stop();
      _controller.value = 0;
      setState(() {});
      return;
    }

    final seconds = (overflow / 28).clamp(2.5, 10.0);
    _controller.duration = Duration(milliseconds: (seconds * 1000).round());
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if ((constraints.maxWidth - _boxWidth).abs() > 0.5) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
          }
          if (!_needsScroll) {
            return Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: widget.style,
            );
          }
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final maxOffset = (_textWidth - _boxWidth).clamp(0.0, 9999.0);
              final dx = -maxOffset * _controller.value;
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                style: widget.style,
              ),
            ),
          );
        },
      ),
    );
  }
}
