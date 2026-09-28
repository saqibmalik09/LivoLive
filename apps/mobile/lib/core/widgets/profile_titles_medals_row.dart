import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';

class ProfileTitlesMedalsRow extends ConsumerWidget {
  const ProfileTitlesMedalsRow({
    super.key,
    required this.userId,
    this.compact = false,
    this.includeLevelBadges = true,
    this.fullBleed = false,
  });

  final String userId;
  final bool compact;
  final bool includeLevelBadges;
  final bool fullBleed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider(userId));

    final levelH = compact ? 16.0 : 20.0;
    final titleH = compact ? 18.0 : 22.0;
    final medalH = compact ? 26.0 : 32.0;
    final gap = compact ? 8.0 : 10.0;

    return badgesAsync.when(
      data: (badges) {
        if (badges.isEmpty) return const SizedBox.shrink();

        final levelBadges = includeLevelBadges
            ? badges
                  .where((b) => b.type != 'medal' && b.type != 'title')
                  .toList()
            : <UserBadgeModel>[];
        final titleBadges = badges.where((b) => b.type == 'title').toList();
        final medalBadges = badges.where((b) => b.type == 'medal').toList();

        if (levelBadges.isEmpty && titleBadges.isEmpty && medalBadges.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (levelBadges.isNotEmpty)
              _HScrollRow(
                height: levelH + 4,
                children: levelBadges
                    .map(
                      (b) => UserBadgeChip(
                        badge: b,
                        height: b.type == 'vip' ? (compact ? 12 : 14) : levelH,
                      ),
                    )
                    .toList(),
              ),
            if (titleBadges.isNotEmpty) ...[
              if (levelBadges.isNotEmpty) SizedBox(height: gap),
              _HScrollRow(
                height: titleH + 4,
                children: titleBadges
                    .map((b) => UserBadgeChip(badge: b, height: titleH))
                    .toList(),
              ),
            ],
            if (medalBadges.isNotEmpty) ...[
              if (levelBadges.isNotEmpty || titleBadges.isNotEmpty)
                SizedBox(height: gap),
              _HScrollRow(
                height: medalH + 4,
                children: medalBadges
                    .map((b) => UserBadgeChip(badge: b, height: medalH))
                    .toList(),
              ),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HScrollRow extends StatelessWidget {
  const _HScrollRow({required this.height, required this.children});

  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    children[i],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
