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
    final onGlass = lightTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: onGlass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.34),
                  Colors.white.withValues(alpha: 0.18),
                ],
              )
            : null,
        color: onGlass ? null : Colors.white,
        border: Border.all(
          color: onGlass
              ? Colors.white.withValues(alpha: 0.55)
              : const Color(0xFFE8ECF4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: onGlass ? 0.12 : 0.06),
            blurRadius: onGlass ? 18 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
          _Divider(lightTheme: lightTheme),
          Expanded(
            child: _StatItem(
              label: context.l10n.profile_following,
              count: following,
              onTap: onFollowingTap,
              lightTheme: lightTheme,
            ),
          ),
          _Divider(lightTheme: lightTheme),
          Expanded(
            child: _StatItem(
              label: context.l10n.profile_friends,
              count: friends,
              onTap: onFriendsTap,
              lightTheme: lightTheme,
            ),
          ),
          _Divider(lightTheme: lightTheme),
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

class _Divider extends StatelessWidget {
  const _Divider({required this.lightTheme});

  final bool lightTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: lightTheme
          ? Colors.white.withValues(alpha: 0.35)
          : const Color(0xFFE2E6EF),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _displayCount,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: lightTheme ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: lightTheme
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF7A8094),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
