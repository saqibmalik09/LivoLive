import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/svga_cache.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class SpecialIdStyle {
  const SpecialIdStyle({
    required this.level,
    required this.name,
    required this.svgaUrl,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final int level;
  final String name;
  final String svgaUrl;
  final Color primaryColor;
  final Color secondaryColor;

  factory SpecialIdStyle.fromMap(Map<String, dynamic> map) {
    return SpecialIdStyle(
      level: (map['level'] as num).toInt(),
      name: map['name']?.toString() ?? 'Style',
      svgaUrl: map['svga_url']?.toString() ?? '',
      primaryColor: _parseColor(
        map['primary_color']?.toString(),
        const Color(0xFFFFD54F),
      ),
      secondaryColor: _parseColor(
        map['secondary_color']?.toString(),
        const Color(0xFFFF8F00),
      ),
    );
  }
}

Color _parseColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

final specialIdStylesProvider = FutureProvider<Map<int, SpecialIdStyle>>((
  ref,
) async {
  final rows = await Supabase.instance.client
      .from('special_id_styles')
      .select('level, name, svga_url, primary_color, secondary_color')
      .eq('is_active', true)
      .order('level');
  final map = <int, SpecialIdStyle>{};
  for (final row in rows as List) {
    final style = SpecialIdStyle.fromMap(Map<String, dynamic>.from(row));
    map[style.level] = style;
  }
  // Warm every crest into the SVGA cache in the background. RaveSVGAPlayer
  // renders nothing until its animation is decoded, and these are 110-190 KB
  // each, so the first time you opened someone's profile their special-ID crest
  // was simply missing — the badge looked like an ordinary chip. Fetched once
  // they persist on disk, so every badge then draws immediately.
  unawaited(_prewarmCrests(map.values));
  return map;
});

Future<void> _prewarmCrests(Iterable<SpecialIdStyle> styles) async {
  for (final style in styles) {
    if (style.svgaUrl.isEmpty) continue;
    try {
      await SvgaCache.load(style.svgaUrl);
    } catch (e) {
      debugPrint('[svga] special-id crest prewarm failed lv${style.level}: $e');
    }
  }
}

class SpecialIdBadge extends ConsumerWidget {
  const SpecialIdBadge({
    super.key,
    required this.id,
    this.level,
    this.height = 22,
    this.onTap,
  });

  final String id;
  final int? level;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stylesAsync = ref.watch(specialIdStylesProvider);
    final style = level == null ? null : stylesAsync.valueOrNull?[level!];

    void copyId() {
      Clipboard.setData(ClipboardData(text: id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID copied'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    if (style == null || style.svgaUrl.isEmpty) {
      // The plain chip draws a copy icon, so it has to actually copy. It was
      // handed the bare onTap — null almost everywhere — so an ID that looked
      // copyable did nothing when tapped. Only the styled badge had the
      // fallback.
      return _PlainIdChip(id: id, onTap: onTap ?? copyId);
    }

    final iconSize = height * 1.55;
    final bubbleHeight = height;
    final crestOverlap = iconSize * 0.42;

    return GestureDetector(
      onTap: onTap ?? copyId,
      child: SizedBox(
        height: iconSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Padding(
              padding: EdgeInsets.only(left: crestOverlap),
              child: Container(
                height: bubbleHeight,
                padding: EdgeInsets.only(
                  left: iconSize - crestOverlap + 4,
                  right: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(bubbleHeight / 2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(style.primaryColor, Colors.white, 0.25)!,
                      style.primaryColor,
                      style.secondaryColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: style.secondaryColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Id3DText(
                      text: id,
                      primary: Colors.white,
                      secondary: style.secondaryColor,
                      fontSize: (bubbleHeight * 0.55).clamp(12.0, 16.0),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.copy_rounded,
                      size: (bubbleHeight * 0.42).clamp(10.0, 14.0),
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: iconSize,
              child: _SpecialIdCrest(url: style.svgaUrl),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialIdCrest extends StatefulWidget {
  const _SpecialIdCrest({required this.url});

  final String url;

  @override
  State<_SpecialIdCrest> createState() => _SpecialIdCrestState();
}

class _SpecialIdCrestState extends State<_SpecialIdCrest> {
  @visibleForTesting
  static const Duration attemptTimeout = Duration(seconds: 8);
  static const int _maxAttempts = 8;
  static const int _maxBackoffSeconds = 8;

  bool _ready = false;
  int _attempt = 0;

  int _generation = 0;
  Timer? _watchdog;
  Timer? _retryTimer;

  bool _lastTryTimedOut = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void didUpdateWidget(_SpecialIdCrest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _begin();
  }

  void _begin() {
    _generation++;
    _watchdog?.cancel();
    _retryTimer?.cancel();
    _attempt = 0;
    _lastTryTimedOut = false;
    final url = widget.url;
    SvgaCache.pin([url]);
    _ready = SvgaCache.isInMemory(url);
    if (!_ready) _try();
  }

  void _try() {
    final gen = _generation;
    _watchdog?.cancel();
    _watchdog = Timer(attemptTimeout, () {
      if (gen != _generation) return;
      _lastTryTimedOut = true;
      _scheduleRetry(gen);
    });
    final fresh = _lastTryTimedOut;
    _lastTryTimedOut = false;
    SvgaCache.load(widget.url, fresh: fresh).then(
      (_) {
        if (!mounted || gen != _generation || _ready) return;
        _watchdog?.cancel();
        _retryTimer?.cancel();
        setState(() => _ready = true);
      },
      onError: (Object e) {
        if (!mounted || gen != _generation || _ready) return;
        debugPrint('[svga] special-id crest try ${_attempt + 1} failed: $e');
        _scheduleRetry(gen);
      },
    );
  }

  void _scheduleRetry(int gen) {
    if (!mounted || gen != _generation || _ready) return;
    _watchdog?.cancel();
    if (_retryTimer?.isActive ?? false) return;
    if (_attempt + 1 >= _maxAttempts) return;
    final seconds = (1 << _attempt).clamp(1, _maxBackoffSeconds);
    _retryTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted || gen != _generation || _ready) return;
      _attempt++;
      _try();
    });
  }

  void _onPlayerError() {
    if (!mounted) return;
    setState(() => _ready = false);
    _scheduleRetry(_generation);
  }

  @override
  void dispose() {
    _generation++;
    _watchdog?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return RaveSVGAPlayer(
      key: ValueKey<String>(widget.url),
      resUrl: widget.url,
      fit: BoxFit.contain,
      repeat: true,
      onFinished: _onPlayerError,
    );
  }
}

class _PlainIdChip extends StatelessWidget {
  const _PlainIdChip({required this.id, this.onTap});

  final String id;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ID:$id',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A5A72),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF5A5A72)),
          ],
        ),
      ),
    );
  }
}

class _Id3DText extends StatelessWidget {
  const _Id3DText({
    required this.text,
    required this.primary,
    required this.secondary,
    required this.fontSize,
  });

  final String text;
  final Color primary;
  final Color secondary;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
      height: 1,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(1.2, 1.4),
          child: Text(
            text,
            style: style.copyWith(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        Transform.translate(
          offset: const Offset(0.5, 0.7),
          child: Text(
            text,
            style: style.copyWith(color: secondary.withValues(alpha: 0.9)),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              primary,
              Color.lerp(primary, secondary, 0.55)!,
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(bounds),
          child: Text(text, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
