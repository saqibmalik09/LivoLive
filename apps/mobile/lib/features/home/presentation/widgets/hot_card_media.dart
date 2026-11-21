import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/home_hot_cards_config_provider.dart';
import 'package:sk_live/core/util/app_image_cache.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';
import 'package:video_player/video_player.dart';

class HotCardMediaWidget extends StatefulWidget {
  const HotCardMediaWidget({
    super.key,
    required this.media,
    this.cacheVersion = '',
    this.borderRadius = 16,
  });

  final HotCardMedia media;
  final String cacheVersion;
  final double borderRadius;

  @override
  State<HotCardMediaWidget> createState() => _HotCardMediaWidgetState();
}

class _HotCardMediaWidgetState extends State<HotCardMediaWidget> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant HotCardMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url ||
        oldWidget.media.mediaType != widget.media.mediaType) {
      _disposeVideo();
      _initVideo();
    }
  }

  void _initVideo() {
    if (widget.media.mediaType != HotCardMediaType.video) return;
    final url = widget.media.versionedUrl(widget.cacheVersion);
    if (url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      setState(() {});
    });
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [_gradientPlaceholder(), _buildContent()],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final media = widget.media;
    final remoteUrl = media.versionedUrl(widget.cacheVersion);

    if (remoteUrl.isNotEmpty) {
      switch (media.mediaType) {
        case HotCardMediaType.svga:
          return SVGAPlayerMuted(resUrl: remoteUrl, fit: BoxFit.cover);
        case HotCardMediaType.video:
          final controller = _videoController;
          if (controller != null && controller.value.isInitialized) {
            return FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            );
          }
          return const SizedBox.shrink();
        case HotCardMediaType.image:
          return CachedNetworkImage(
            cacheManager: AppImageCache.manager,
            imageUrl: remoteUrl,
            cacheKey: '${remoteUrl}_${widget.cacheVersion}',
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _gradientPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFE040FB)],
        ),
      ),
    );
  }
}
