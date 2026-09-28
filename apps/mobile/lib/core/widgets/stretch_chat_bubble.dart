import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';

bool isNineSliceChatBubble({String? name, String? imageUrl}) {
  final hay = '${name ?? ''} ${imageUrl ?? ''}'.toLowerCase();
  if (hay.contains('.9png') || hay.contains('9png') || hay.contains('9.png')) {
    return true;
  }
  if ((hay.contains('vip') || hay.contains('气泡')) &&
      (hay.contains('bub') || hay.contains('bubble') || hay.contains('气泡'))) {
    return true;
  }
  return false;
}

class StretchChatBubble extends StatefulWidget {
  const StretchChatBubble({
    super.key,
    required this.networkUrl,
    required this.child,
    this.svgaUrl,
    this.maxWidth,
    this.padding = const EdgeInsets.fromLTRB(22, 14, 28, 16),
    this.displayScale = 2.35,
    this.animate = true,
  });

  final String networkUrl;

  final String? svgaUrl;
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry padding;
  final double displayScale;
  final bool animate;

  @override
  State<StretchChatBubble> createState() => _StretchChatBubbleState();
}

class _StretchChatBubbleState extends State<StretchChatBubble>
    with SingleTickerProviderStateMixin {
  ui.Image? _cropped;
  String? _loadedUrl;
  bool _loadFailed = false;
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.animate) {
      _shine.repeat();
    }
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant StretchChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkUrl != widget.networkUrl) {
      unawaited(_load());
    }
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _shine.repeat();
      } else {
        _shine.stop();
        _shine.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    _cropped?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = widget.networkUrl.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    _loadedUrl = url;
    if (mounted) {
      setState(() {
        _loadFailed = false;
        _cropped?.dispose();
        _cropped = null;
      });
    }
    try {
      final provider = CachedNetworkImageProvider(url);
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          stream.removeListener(listener);
          completer.complete(info.image);
        },
        onError: (e, st) {
          stream.removeListener(listener);
          completer.completeError(e, st);
        },
      );
      stream.addListener(listener);
      final full = await completer.future;
      if (!mounted || _loadedUrl != url) {
        full.dispose();
        return;
      }
      final cropped = await _cropOpaque(full);
      full.dispose();
      if (!mounted || _loadedUrl != url) {
        cropped.dispose();
        return;
      }
      setState(() {
        _cropped?.dispose();
        _cropped = cropped;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || _loadedUrl != url) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<ui.Image> _cropOpaque(ui.Image src) async {
    final w = src.width;
    final h = src.height;
    final bytes = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return src;

    var minX = w;
    var minY = h;
    var maxX = 0;
    var maxY = 0;
    final data = bytes.buffer.asUint8List();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final a = data[(y * w + x) * 4 + 3];
        if (a > 12) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX <= minX || maxY <= minY) return src;

    const pad = 4;
    minX = (minX - pad).clamp(0, w - 1);
    minY = (minY - pad).clamp(0, h - 1);
    maxX = (maxX + pad).clamp(0, w - 1);
    maxY = (maxY + pad).clamp(0, h - 1);
    final cw = maxX - minX + 1;
    final ch = maxY - minY + 1;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(
        minX.toDouble(),
        minY.toDouble(),
        cw.toDouble(),
        ch.toDouble(),
      ),
      Rect.fromLTWH(0, 0, cw.toDouble(), ch.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    return picture.toImage(cw, ch);
  }

  @override
  Widget build(BuildContext context) {
    final img = _cropped;
    final svga = widget.svgaUrl?.trim();
    final hasSvga = svga != null && svga.isNotEmpty;

    if (img == null && _loadFailed) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth ?? double.infinity,
          minHeight: 48,
        ),
        child: Padding(padding: widget.padding, child: widget.child),
      );
    }

    if (img == null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth ?? double.infinity,
          minHeight: 48,
        ),
        child: Opacity(
          opacity: 0,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      );
    }

    final scale = widget.displayScale;
    final srcW = img.width.toDouble();
    final srcH = img.height.toDouble();
    final center = Rect.fromLTRB(
      srcW * 0.24,
      srcH * 0.28,
      srcW * 0.74,
      srcH * 0.72,
    );
    final minW = (center.left + (srcW - center.right)) / scale + 8;
    final minH = (center.top + (srcH - center.bottom)) / scale + 8;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minW,
        minHeight: minH,
        maxWidth: widget.maxWidth ?? double.infinity,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _shine,
              builder: (context, _) {
                return CustomPaint(
                  painter: _NineSlicePainter(
                    image: img,
                    centerSlice: center,
                    scale: scale,
                    shineT: widget.animate ? _shine.value : 0,
                  ),
                );
              },
            ),
          ),
          if (hasSvga)
            Positioned.fill(
              child: IgnorePointer(
                child: SVGAPlayerMuted(resUrl: svga, fit: BoxFit.fill),
              ),
            ),
          Padding(padding: widget.padding, child: widget.child),
        ],
      ),
    );
  }
}

class _NineSlicePainter extends CustomPainter {
  _NineSlicePainter({
    required this.image,
    required this.centerSlice,
    required this.scale,
    required this.shineT,
  });

  final ui.Image image;
  final Rect centerSlice;
  final double scale;
  final double shineT;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(1 / scale, 1 / scale);
    final dst = Rect.fromLTWH(0, 0, size.width * scale, size.height * scale);
    canvas.drawImageNine(
      image,
      centerSlice,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    if (shineT <= 0) return;

    final sweep = (shineT * 1.6) - 0.3;
    final paint = Paint()
      ..blendMode = BlendMode.softLight
      ..shader = LinearGradient(
        begin: Alignment(-1.2 + sweep * 2.4, -0.4),
        end: Alignment(-0.4 + sweep * 2.4, 0.4),
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NineSlicePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.centerSlice != centerSlice ||
        oldDelegate.scale != scale ||
        (oldDelegate.shineT - shineT).abs() > 0.01;
  }
}

class VipChatBubbleAssets {
  VipChatBubbleAssets._();

  static const vip4 = 'assets/chat/bubbles/vip4.png';
  static const vip5 = 'assets/chat/bubbles/vip5.png';
  static const vip6 = 'assets/chat/bubbles/vip6.png';

  static const all = <({String label, String asset})>[
    (label: 'VIP 4', asset: vip4),
    (label: 'VIP 5', asset: vip5),
    (label: 'VIP 6', asset: vip6),
  ];
}
