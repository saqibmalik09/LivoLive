import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';
import 'package:sk_live/features/home/presentation/pages/open_party_event.dart';
import 'package:sk_live/features/home/presentation/pages/sk_party/sk_party_assets.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_assets.dart';

class PartyEventsTab extends ConsumerWidget {
  const PartyEventsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(partyEventsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(partyEventsProvider),
      color: AppColors.primary,
      child: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                homeTabScrollBottomPadding(context),
              ),
              children: [
                const SizedBox(height: 48),
                Icon(
                  Iconsax.calendar,
                  size: 56,
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No events right now',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Check back soon for new campaigns',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              homeTabScrollBottomPadding(context),
            ),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              return _EventCard(
                event: event,
                onTap: () => _openEvent(context, event),
              );
            },
          );
        },
        loading: () => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            homeTabScrollBottomPadding(context),
          ),
          itemCount: 4,
          itemBuilder: (_, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: AppColors.shimmerBase,
              highlightColor: AppColors.shimmerHighlight,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        error: (_, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            12,
            40,
            12,
            homeTabScrollBottomPadding(context),
          ),
          children: const [
            Text(
              'Could not load events',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  void _openEvent(BuildContext context, PartyEvent event) {
    openPartyEvent(context, event);
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final PartyEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCpNative = event.eventKind == PartyEventKind.cpNative;
    final isWeeklyStar = event.eventKind == PartyEventKind.weeklyStarNative;
    final isGameStar = event.eventKind == PartyEventKind.gameStarNative;
    final isSkHost = event.eventKind == PartyEventKind.skHostNative;
    final hasUploadedBanner = event.bannerUrl.isNotEmpty;
    final useBundledBanner =
        !hasUploadedBanner &&
        (isCpNative || isWeeklyStar || isGameStar || isSkHost);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 7,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasUploadedBanner)
                CachedNetworkImage(
                  imageUrl: event.versionedBannerUrl,
                  cacheKey: '${event.id}_${event.cacheVersion}',
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  placeholder: (_, _) => Container(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.primaryUltraLight,
                    child: const Icon(
                      Iconsax.image,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                )
              else if (isCpNative)
                Image.asset(
                  CpEventAssets.banner,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF2A1035),
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFFFF69B4),
                      size: 40,
                    ),
                  ),
                )
              else if (isWeeklyStar)
                Image.asset(
                  WeeklyStarAssets.banner,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF1A1040),
                    child: const Icon(
                      Icons.star,
                      color: Color(0xFFFFD54F),
                      size: 40,
                    ),
                  ),
                )
              else if (isGameStar)
                Image.asset(
                  GameStarAssets.banner,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF2A0A0A),
                    child: const Icon(
                      Icons.sports_esports,
                      color: Color(0xFFFFD54F),
                      size: 40,
                    ),
                  ),
                )
              else if (isSkHost)
                Image.asset(
                  SkPartyAssets.banner,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF0D1B2A),
                    child: const Icon(
                      Icons.celebration,
                      color: Color(0xFFFFD54F),
                      size: 40,
                    ),
                  ),
                )
              else
                Container(
                  color: AppColors.primaryUltraLight,
                  child: const Icon(
                    Iconsax.image,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              if (!useBundledBanner &&
                  (event.title.isNotEmpty || event.subtitle.isNotEmpty))
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (event.title.isNotEmpty)
                        Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black54),
                            ],
                          ),
                        ),
                      if (event.subtitle.isNotEmpty)
                        Text(
                          event.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black45),
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
    );
  }
}
