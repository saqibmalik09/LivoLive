import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/home/services/ranking_room_promo_service.dart';

class RankingRoomPromoPopup extends StatelessWidget {
  const RankingRoomPromoPopup({
    super.key,
    required this.promo,
    required this.onEnter,
    required this.onDismiss,
  });

  final RankingRoomPromo promo;
  final VoidCallback onEnter;
  final VoidCallback onDismiss;

  static Future<bool> show(
    BuildContext context, {
    required RankingRoomPromo promo,
    required Future<void> Function() onEnter,
  }) async {
    final entered = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Ranking room',
      barrierColor: Colors.black.withValues(alpha: 0.68),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, secondary) {
        return RankingRoomPromoPopup(
          promo: promo,
          onEnter: () => Navigator.of(ctx).pop(true),
          onDismiss: () => Navigator.of(ctx).pop(false),
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
    if (entered == true) {
      await onEnter();
      return true;
    }
    return false;
  }

  String _headline(BuildContext context) {
    if (promo.rank == 1) return context.l10n.ranking_todaysTopRoom;
    if (promo.rank == 3) return 'Rising Star — #3';
    return 'Top Room #${promo.rank}';
  }

  String get _subtitle {
    if (promo.rank == 1) {
      return 'The hottest room on the leaderboard right now. Jump in and feel the vibe.';
    }
    if (promo.rank == 3) {
      return 'A top-three room packed with energy. Step inside and say hello.';
    }
    return 'A featured room from today’s rankings. Tap Enter to join.';
  }

  String get _badgeLabel {
    if (promo.rank == 1) return 'NO. 1';
    if (promo.rank == 3) return 'NO. 3';
    return 'NO. ${promo.rank}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(0, 340).toDouble();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width - 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF6E8),
                      Color(0xFFFFE8C2),
                      Color(0xFFFFD89A),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE8B84A).withValues(alpha: 0.85),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(21),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (promo.imageUrl != null &&
                                promo.imageUrl!.trim().isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: promo.imageUrl!,
                                fit: BoxFit.cover,
                                // Decode at card size, not the upload's.
                                memCacheWidth: 720,
                                fadeInDuration: const Duration(milliseconds: 120),
                                errorWidget: (_, _, _) => _coverFallback(),
                              )
                            else
                              _coverFallback(),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.05),
                                    Colors.black.withValues(alpha: 0.55),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              bottom: 12,
                              right: 12,
                              child: Text(
                                promo.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFE082),
                                      Color(0xFFFFB300),
                                      Color(0xFFE65100),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFE65100,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _badgeLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _headline(context),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4A2A12),
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF7A5A40),
                            ),
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: onEnter,
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFFF59D),
                                    Color(0xFFFFB300),
                                    Color(0xFFFF6F00),
                                    Color(0xFFE65100),
                                  ],
                                  stops: [0.0, 0.35, 0.7, 1.0],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFFFE082),
                                  width: 1.6,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF6F00,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                context.l10n.ranking_enterRoom,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              context.l10n.ranking_maybeLater,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8B6A4A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 22,
                right: 6,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF6A5040),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCC80), Color(0xFFFF8A65), Color(0xFFBF360C)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.meeting_room_rounded,
          color: Colors.white70,
          size: 48,
        ),
      ),
    );
  }
}
