import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class FollowRelationshipButton extends ConsumerWidget {
  const FollowRelationshipButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
    this.onDarkBackground = false,
  });

  final String targetUserId;
  final bool compact;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationshipAsync = ref.watch(
      followRelationshipProvider(targetUserId),
    );

    return relationshipAsync.when(
      data: (state) {
        if (state == FollowRelationshipState.self) {
          return const SizedBox.shrink();
        }
        return _FollowChip(
          state: state,
          compact: compact,
          onDarkBackground: onDarkBackground,
          onTap: () async {
            await HapticFeedback.lightImpact();
            final currentlyFollowed =
                state == FollowRelationshipState.following ||
                state == FollowRelationshipState.friends;
            await SocialService.toggleFollow(
              ref,
              targetUserId,
              currentlyFollowed,
            );
          },
        );
      },
      loading: () => SizedBox(
        width: compact ? 16 : 20,
        height: compact ? 16 : 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: onDarkBackground ? Colors.white54 : AppColors.primary,
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FollowChip extends StatelessWidget {
  const _FollowChip({
    required this.state,
    required this.compact,
    required this.onDarkBackground,
    this.onTap,
  });

  final FollowRelationshipState state;
  final bool compact;
  final bool onDarkBackground;
  final VoidCallback? onTap;

  String _label(BuildContext context) {
    final l10n = context.l10n;
    switch (state) {
      case FollowRelationshipState.friends:
        return l10n.profile_friends;
      case FollowRelationshipState.following:
        return l10n.profile_unfollow;
      case FollowRelationshipState.followBack:
        return l10n.profile_follow;
      case FollowRelationshipState.none:
        return l10n.profile_follow;
      case FollowRelationshipState.self:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFriend = state == FollowRelationshipState.friends;
    final isFollowing = state == FollowRelationshipState.following;
    final isFollowBack = state == FollowRelationshipState.followBack;

    final horizontal = compact ? 8.0 : 12.0;
    final vertical = compact ? 4.0 : 6.0;
    final fontSize = compact ? 10.0 : 11.0;

    Color textColor;
    BoxDecoration decoration;

    if (isFriend) {
      textColor = onDarkBackground
          ? const Color(0xFF7EE787)
          : const Color(0xFF2E7D32);
      decoration = BoxDecoration(
        color: onDarkBackground
            ? const Color(0xFF7EE787).withValues(alpha: 0.15)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onDarkBackground
              ? const Color(0xFF7EE787).withValues(alpha: 0.4)
              : const Color(0xFF81C784),
        ),
      );
    } else if (isFollowing) {
      textColor = onDarkBackground ? Colors.white70 : AppColors.textSecondary;
      decoration = BoxDecoration(
        color: onDarkBackground ? Colors.white10 : const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onDarkBackground ? Colors.white24 : Colors.black12,
        ),
      );
    } else if (isFollowBack) {
      textColor = Colors.white;
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
        ),
        borderRadius: BorderRadius.circular(20),
      );
    } else {
      textColor = Colors.white;
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, Color(0xFFFF69B4)],
        ),
        borderRadius: BorderRadius.circular(20),
      );
    }

    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: decoration,
      child: Text(
        _label(context),
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
