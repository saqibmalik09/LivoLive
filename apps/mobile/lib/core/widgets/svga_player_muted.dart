import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

class SVGAPlayerMuted extends StatefulWidget {
  final String resUrl;
  final BoxFit fit;

  const SVGAPlayerMuted({
    super.key,
    required this.resUrl,
    this.fit = BoxFit.contain,
  });

  @override
  State<SVGAPlayerMuted> createState() => _SVGAPlayerMutedState();
}

class _SVGAPlayerMutedState extends State<SVGAPlayerMuted>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this)..muted = true;
    _loadAnimation();
  }

  @override
  void didUpdateWidget(SVGAPlayerMuted oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resUrl != widget.resUrl) {
      _loadAnimation();
    }
  }

  Future<void> _loadAnimation() async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(widget.resUrl);
      if (mounted && _controller != null) {
        setState(() {
          _controller!.videoItem = videoItem;
          _controller!.repeat();
        });
      } else {
        videoItem.dispose();
      }
    } catch (e) {
      debugPrint('Error loading SVGA: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _controller!.videoItem == null) {
      return const SizedBox.shrink();
    }
    return SVGAImage(_controller!, fit: widget.fit);
  }
}
