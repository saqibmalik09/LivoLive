import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/cp_nest_screen.dart';

class CpEventMyRankBar extends StatelessWidget {
  const CpEventMyRankBar({
    super.key,
    this.me,
    this.fallbackName,
    this.fallbackAvatar,
  });

  final CpEventCoupleRank? me;
  final String? fallbackName;
  final String? fallbackAvatar;

  @override
  Widget build(BuildContext context) {
    final rankText = (me != null && me!.rank > 0) ? '${me!.rank}' : '--';
    final score = me?.score ?? 0;
    final name1 = (me?.user1Name?.trim().isNotEmpty == true)
        ? me!.user1Name!.trim()
        : (fallbackName?.trim().isNotEmpty == true
              ? fallbackName!.trim()
              : 'User');
    final name2 = me?.user2Name?.trim().isNotEmpty == true
        ? me!.user2Name!.trim()
        : '--';
    final hasPartner = me != null && me!.user2Id.isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: SizedBox(
          height: 72,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  CpEventAssets.footerProfileCard,
                  fit: BoxFit.fill,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        rankText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF5C2E00),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _AvatarWithGo(
                      avatarUrl: me?.user1Avatar ?? fallbackAvatar,
                      partnerAvatarUrl: hasPartner ? me!.user2Avatar : null,
                      showGo: !hasPartner,
                      onGo: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CPNestScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF4A2800),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(
                                0xFF4A2800,
                              ).withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.favorite,
                      color: Color(0xFFE91E63),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatCpEventScore(score),
                      style: const TextStyle(
                        color: Color(0xFF4A2800),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarWithGo extends StatelessWidget {
  const _AvatarWithGo({
    required this.avatarUrl,
    required this.partnerAvatarUrl,
    required this.showGo,
    required this.onGo,
  });

  final String? avatarUrl;
  final String? partnerAvatarUrl;
  final bool showGo;
  final VoidCallback onGo;

  static const double _size = 40;
  static const double _overlap = 12;

  @override
  Widget build(BuildContext context) {
    final width = _size * 2 - _overlap;
    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, child: _circleAvatar(avatarUrl)),
          Positioned(
            left: _size - _overlap,
            child: showGo
                ? GestureDetector(
                    onTap: onGo,
                    child: Container(
                      width: _size,
                      height: _size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFCE93D8), Color(0xFF7B1FA2)],
                        ),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        'GO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  )
                : _circleAvatar(partnerAvatarUrl),
          ),
        ],
      ),
    );
  }

  Widget _circleAvatar(String? url) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey[700]),
                errorWidget: (_, _, _) => Container(
                  color: Colors.grey[700],
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              )
            : Container(
                color: Colors.grey[700],
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
      ),
    );
  }
}
