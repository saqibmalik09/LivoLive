import 'package:flutter/material.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/room_cover_cache.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/widgets/room_background_media.dart';

class HomeRefRoomCard extends StatelessWidget {
  const HomeRefRoomCard({
    super.key,
    required this.room,
    required this.giftTotal,
    required this.flag,
    required this.hostName,
    required this.locked,
    required this.onTap,
  });

  final Map<String, dynamic> room;
  final int giftTotal;
  final Widget flag;
  final String hostName;
  final bool locked;
  final VoidCallback onTap;

  static const double designWidth = 750;

  static const double side = 28;
  static const double gap = 13;
  static const double coverHeight = 340;
  static const double cardHeight = 402;

  static double scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  @override
  Widget build(BuildContext context) {
    final s = scaleOf(context);
    final title = room['title']?.toString() ?? '';
    final hostAvatar = room['host_avatar']?.toString() ?? '';
    final cover = room['image_url']?.toString() ?? '';
    final online = (room['online_users_count'] as num?)?.toInt() ?? 0;
    warmRoomBackgroundToDisk(context, room['background_url']?.toString());
    final pillText = TextStyle(
      color: Colors.white,
      fontSize: 22 * s,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: coverHeight * s,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20 * s),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final cacheW = roomCoverCacheWidth(context);
                        retainRoomCover(cover, cacheW);
                        return AppNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          gaplessPlayback: true,
                          cacheKey: roomCoverCacheKey(cover, cacheW),
                          transformWidth: cacheW,
                          transformHeight: cacheW,
                          memCacheWidth: cacheW,
                          memCacheHeight: cacheW,
                        );
                      },
                    )
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2D1B4E), Color(0xFF1A0A2E)],
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.22, 0.72, 1],
                        colors: [
                          Color(0x40000000),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x59000000),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14 * s,
                    top: 12 * s,
                    right: 110 * s,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        height: 40 * s,
                        padding: EdgeInsets.symmetric(horizontal: 14 * s),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(20 * s),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (locked) ...[
                              Icon(
                                Icons.lock_rounded,
                                size: 22 * s,
                                color: Colors.amber,
                              ),
                              SizedBox(width: 6 * s),
                            ],
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: pillText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12 * s,
                    top: 12 * s,
                    child: Container(
                      height: 40 * s,
                      padding: EdgeInsets.symmetric(horizontal: 12 * s),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(20 * s),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 22 * s,
                            color: const Color(0xFFFF8A3D),
                          ),
                          SizedBox(width: 4 * s),
                          Text(
                            NumberFormatter.format(giftTotal),
                            style: pillText.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16 * s,
                    bottom: 14 * s,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.equalizer_rounded,
                          size: 30 * s,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4 * s),
                        Text(
                          '$online',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26 * s,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            shadows: const [
                              Shadow(color: Color(0x66000000), blurRadius: 3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          SizedBox(
            height: 50 * s,
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 50 * s,
                    child: hostAvatar.isNotEmpty
                        ? AppNetworkImage(
                            imageUrl: hostAvatar,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            transformWidth: 96,
                            transformHeight: 96,
                            memCacheWidth: 96,
                            memCacheHeight: 96,
                          )
                        : const ColoredBox(
                            color: Color(0xFFDCEFE9),
                            child: Icon(Icons.person, color: Color(0xFF8BB8AC)),
                          ),
                  ),
                ),
                SizedBox(width: 8 * s),
                flag,
                SizedBox(width: 8 * s),
                Expanded(
                  child: Text(
                    hostName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF333333),
                      fontSize: 28 * s,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
