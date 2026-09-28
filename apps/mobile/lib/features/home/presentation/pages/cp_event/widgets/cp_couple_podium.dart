import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_couple_avatar_pair.dart';

class CpTop1Frame extends StatelessWidget {
  const CpTop1Frame({super.key, this.couple, this.width = 280});

  final CpEventCoupleRank? couple;
  final double width;

  @override
  Widget build(BuildContext context) {
    final avatarSize = width * 0.20;
    final gap = width * 0.28;
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (couple != null)
              Positioned(
                top: width * 0.38,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _top1Avatar(couple!.user1Avatar, avatarSize),
                    SizedBox(width: gap),
                    _top1Avatar(couple!.user2Avatar, avatarSize),
                  ],
                ),
              ),
            Positioned.fill(
              child: Image.asset(CpEventAssets.top1, fit: BoxFit.contain),
            ),
            if (couple != null)
              Positioned(
                bottom: width * 0.26,
                left: width * 0.18,
                right: width * 0.18,
                child: Text(
                  couple!.displayNames,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _top1Avatar(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[800]),
                errorWidget: (_, _, _) => Container(
                  color: Colors.grey[800],
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: size * 0.45,
                  ),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: size * 0.45,
                ),
              ),
      ),
    );
  }
}

class CpTop3Board extends StatelessWidget {
  const CpTop3Board({
    super.key,
    this.top1,
    this.top2,
    this.top3,
    this.width,
    this.headerTitle,
    this.headerSubtitle,
  });

  final CpEventCoupleRank? top1;
  final CpEventCoupleRank? top2;
  final CpEventCoupleRank? top3;
  final double? width;
  final String? headerTitle;
  final String? headerSubtitle;

  static const double _aspect = 399 / 600;

  @override
  Widget build(BuildContext context) {
    final w = width ?? MediaQuery.sizeOf(context).width - 24;
    final h = w / _aspect;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          if (top1 != null)
            _coupleSlot(
              boardW: w,
              boardH: h,
              couple: top1!,
              leftFrac: 0.215,
              topFrac: 0.28,
              avatarSizeFrac: 0.195,
              gapFrac: 0.16,
            ),
          if (top2 != null)
            _coupleSlot(
              boardW: w,
              boardH: h,
              couple: top2!,
              leftFrac: 0.05,
              topFrac: 0.68,
              avatarSizeFrac: 0.15,
              gapFrac: 0.075,
            ),
          if (top3 != null)
            _coupleSlot(
              boardW: w,
              boardH: h,
              couple: top3!,
              leftFrac: 0.53,
              topFrac: 0.69,
              avatarSizeFrac: 0.15,
              gapFrac: 0.09,
            ),
          Positioned.fill(
            child: Image.asset(CpEventAssets.top3, fit: BoxFit.fill),
          ),
          if (headerTitle != null && headerTitle!.isNotEmpty)
            Positioned(
              left: w * 0.22,
              top: h * 0.022,
              width: w * 0.56,
              height: h * 0.055,
              child: Center(
                child: Text(
                  headerTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                  ),
                ),
              ),
            ),
          if (headerSubtitle != null && headerSubtitle!.isNotEmpty)
            Positioned(
              left: w * 0.30,
              top: h * 0.144,
              width: w * 0.40,
              height: h * 0.04,
              child: Center(
                child: Text(
                  headerSubtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A2800),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          if (top1 != null) ...[
            Positioned(
              left: w * 0.18,
              top: h * 0.46,
              width: w * 0.64,
              child: Text(
                top1!.displayNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                ),
              ),
            ),
            Positioned(
              left: w * 0.18,
              top: h * 0.555,
              width: w * 0.64,
              child: Text(
                formatCpEventScore(top1!.score),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFF59D),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                ),
              ),
            ),
          ],
          if (top2 != null) ...[
            Positioned(
              left: w * 0.04,
              top: h * 0.82,
              width: w * 0.42,
              child: Text(
                top2!.displayNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                ),
              ),
            ),
            Positioned(
              left: w * 0.04,
              top: h * 0.875,
              width: w * 0.42,
              child: Text(
                formatCpEventScore(top2!.score),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFF59D),
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                ),
              ),
            ),
          ],
          if (top3 != null) ...[
            Positioned(
              left: w * 0.56,
              top: h * 0.82,
              width: w * 0.42,
              child: Text(
                top3!.displayNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                ),
              ),
            ),
            Positioned(
              left: w * 0.56,
              top: h * 0.875,
              width: w * 0.42,
              child: Text(
                formatCpEventScore(top3!.score),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFF59D),
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coupleSlot({
    required double boardW,
    required double boardH,
    required CpEventCoupleRank couple,
    required double leftFrac,
    required double topFrac,
    required double avatarSizeFrac,
    required double gapFrac,
  }) {
    final size = boardW * avatarSizeFrac;
    final gap = boardW * gapFrac;
    return Positioned(
      left: boardW * leftFrac,
      top: boardH * topFrac,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circleAvatar(couple.user1Avatar, size),
          SizedBox(width: gap),
          _circleAvatar(couple.user2Avatar, size),
        ],
      ),
    );
  }

  Widget _circleAvatar(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[800]),
                errorWidget: (_, _, _) => Container(
                  color: Colors.grey[800],
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: size * 0.45,
                  ),
                ),
              )
            : Container(
                color: Colors.grey[800],
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: size * 0.45,
                ),
              ),
      ),
    );
  }

  Widget _infoLabel({
    required double boardW,
    required double boardH,
    required CpEventCoupleRank couple,
    required double leftFrac,
    required double topFrac,
    required double widthFrac,
    required double fontSize,
  }) {
    return Positioned(
      left: boardW * leftFrac,
      top: boardH * topFrac,
      width: boardW * widthFrac,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            couple.displayNames,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatCpEventScore(couple.score),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFFF59D),
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
            ),
          ),
        ],
      ),
    );
  }
}

class CpTop3Frame extends StatelessWidget {
  const CpTop3Frame({
    super.key,
    required this.couple,
    this.width = 140,
    this.showScore = true,
    this.badgeLabel,
  });

  final CpEventCoupleRank? couple;
  final double width;
  final bool showScore;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final avatarSize = width * 0.28;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badgeLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              badgeLabel!,
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ),
        SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 1.35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (couple != null)
                  Positioned(
                    top: width * 0.18,
                    child: CpCoupleAvatarPair(
                      avatar1: couple!.user1Avatar,
                      avatar2: couple!.user2Avatar,
                      size: avatarSize,
                      overlap: avatarSize * 0.2,
                    ),
                  ),
                Positioned.fill(
                  child: Image.asset(CpEventAssets.top3, fit: BoxFit.contain),
                ),
              ],
            ),
          ),
        ),
        if (couple != null) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: width,
            child: Text(
              couple!.displayNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          if (showScore)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6BA8).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD54F), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    formatCpEventScore(couple!.score),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class CpRewardGiftSlot extends StatelessWidget {
  const CpRewardGiftSlot({
    super.key,
    required this.imageUrl,
    required this.label,
    this.size = 72,
  });

  final String imageUrl;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (imageUrl.isNotEmpty)
                Padding(
                  padding: EdgeInsets.all(size * 0.18),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.card_giftcard, color: Colors.white54),
                  ),
                ),
              Positioned.fill(
                child: Image.asset(
                  CpEventAssets.topGiftFrame,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
