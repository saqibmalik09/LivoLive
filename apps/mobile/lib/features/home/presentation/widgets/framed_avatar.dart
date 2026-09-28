import 'package:flutter/material.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/widgets/ranking_frame_media.dart';

class FramedAvatar extends StatelessWidget {
  const FramedAvatar({
    super.key,
    this.avatarUrl,
    this.frameUrl,
    required this.size,
    this.fallbackIcon = Icons.person,
    this.fallbackIconColor,
    this.frameScale = 1.35,
  });

  final String? avatarUrl;
  final String? frameUrl;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;
  final double frameScale;

  @override
  Widget build(BuildContext context) {
    final trimmedFrame = frameUrl?.trim() ?? '';
    final hasFrame = trimmedFrame.isNotEmpty;
    final frameSize = size * frameScale;
    final transformPx = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(64, 256);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasFrame
            ? null
            : Border.all(color: const Color(0xFFFFD54F), width: 2),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? AppNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                transformWidth: transformPx,
                transformHeight: transformPx,
                memCacheWidth: transformPx,
                memCacheHeight: transformPx,
                errorWidget: (_, _, _) => Icon(
                  fallbackIcon,
                  size: size * 0.5,
                  color: fallbackIconColor ?? Colors.grey,
                ),
              )
            : Icon(
                fallbackIcon,
                size: size * 0.5,
                color: fallbackIconColor ?? Colors.grey,
              ),
      ),
    );

    if (!hasFrame) return avatar;

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          avatar,
          RankingFrameMedia(
            url: trimmedFrame,
            width: frameSize,
            height: frameSize,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
