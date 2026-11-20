import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class MyProfileStatsRow extends StatelessWidget {
  const MyProfileStatsRow({
    super.key,
    required this.followers,
    required this.following,
    required this.friends,
    required this.visits,
    this.onFollowersTap,
    this.onFollowingTap,
    this.onFriendsTap,
    this.onVisitsTap,
    this.lightTheme = false,
  });

  final int followers;
  final int following;
  final int friends;
  final int visits;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFriendsTap;
  final VoidCallback? onVisitsTap;
  final bool lightTheme;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 750;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * s),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: context.l10n.profile_followers,
              count: followers,
              onTap: onFollowersTap,
              lightTheme: lightTheme,
            ),
          ),
          Expanded(
            child: _StatItem(
              label: context.l10n.profile_following,
              count: following,
              onTap: onFollowingTap,
              lightTheme: lightTheme,
            ),
          ),
          Expanded(
            child: _StatItem(
              label: context.l10n.profile_friends,
              count: friends,
              onTap: onFriendsTap,
              lightTheme: lightTheme,
            ),
          ),
          Expanded(
            child: _StatItem(
              label: context.l10n.profile_visits,
              count: visits,
              onTap: onVisitsTap,
              lightTheme: lightTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.count,
    this.onTap,
    this.lightTheme = false,
  });

  final String label;
  final int count;
  final VoidCallback? onTap;
  final bool lightTheme;

  String get _displayCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 750;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _displayCount,
              style: TextStyle(
                fontSize: 34 * s,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                height: 1.2,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 29 * s,
                color: const Color(0xFF56605D),
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
