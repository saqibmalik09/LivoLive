import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/widgets/copy_on_long_press.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/display_user_id.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/widgets/follow_relationship_button.dart';
import 'package:sk_live/core/widgets/special_id_badge.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';
import 'package:sk_live/core/widgets/user_member_identity.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileMiniRoomActions {
  const UserProfileMiniRoomActions({
    this.onMute,
    this.onBanChat,
    this.onStandUp,
    this.onKick,
    this.onSayHi,
    this.onReminder,
    this.onSendGift,
    this.showMute = false,
    this.showBanChat = false,
    this.showStandUp = false,
    this.showKick = false,
    this.forceModRow = false,
  });

  final VoidCallback? onMute;
  final VoidCallback? onBanChat;
  final VoidCallback? onStandUp;
  final VoidCallback? onKick;
  final void Function(String username)? onSayHi;
  final void Function(String username)? onReminder;
  final VoidCallback? onSendGift;

  final bool showMute;
  final bool showBanChat;
  final bool showStandUp;
  final bool showKick;
  final bool forceModRow;

  bool get hasModRow =>
      forceModRow || showMute || showBanChat || showStandUp || showKick;
}

class UserProfileMiniSheet {
  UserProfileMiniSheet._();

  static Future<void> show(
    BuildContext context,
    String userId, {
    VoidCallback? onSendGift,
    VoidCallback? onMention,
    UserProfileMiniRoomActions? roomActions,
  }) {
    if (userId.isEmpty) return Future.value();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      clipBehavior: Clip.none,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 140),
        reverseDuration: Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height;
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;
        const avatarFloat = 28.0;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.88),
            child: Padding(
              padding: const EdgeInsets.only(top: avatarFloat),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.none,
                child: _UserProfileMiniSheetBody(
                  userId: userId,
                  onSendGift: onSendGift ?? roomActions?.onSendGift,
                  onMention: onMention,
                  roomActions: roomActions,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserProfileMiniSheetBody extends ConsumerStatefulWidget {
  const _UserProfileMiniSheetBody({
    required this.userId,
    this.onSendGift,
    this.onMention,
    this.roomActions,
  });

  final String userId;
  final VoidCallback? onSendGift;
  final VoidCallback? onMention;
  final UserProfileMiniRoomActions? roomActions;

  @override
  ConsumerState<_UserProfileMiniSheetBody> createState() =>
      _UserProfileMiniSheetBodyState();
}

class _UserProfileMiniSheetBodyState
    extends ConsumerState<_UserProfileMiniSheetBody> {
  static const double _avatarRadius = 40;
  static double get _avatarFrameSize => _avatarRadius * 2.75;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(recordProfileVisit(widget.userId));
    });
  }

  String get userId => widget.userId;

  int? _ageFromBirth(dynamic dob) {
    if (dob == null) return null;
    final parsed = DateTime.tryParse(dob.toString());
    if (parsed == null) return null;
    final now = DateTime.now();
    var age = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      age--;
    }
    return age;
  }

  String? _countryName(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return null;
    try {
      return Country.parse(countryCode).name;
    } catch (_) {
      return countryCode;
    }
  }

  String _flagEmoji(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return '';
    try {
      return Country.parse(countryCode).flagEmoji;
    } catch (_) {
      return '';
    }
  }

  void _openFullProfile(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRouter.userProfile, extra: userId);
  }

  void _runAfterSheetClose(VoidCallback? action) {
    if (action == null) return;
    Navigator.of(context).pop();
    Future<void>.delayed(const Duration(milliseconds: 120), action);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(publicUserProfileProvider(userId));

    return userAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => _OuterCard(
        child: const SizedBox(
          height: 160,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return _OuterCard(
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'User not found',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return _buildContent(context, user);
      },
      error: (e, _) => _OuterCard(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            e.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> user) {
    final vipLevel = (user['vip_level'] as num?)?.toInt() ?? 0;
    final username = user['username']?.toString() ?? 'User';
    final avatarUrl = user['avatar_url']?.toString();
    final gender = user['gender']?.toString();
    final countryCode = user['country_code']?.toString();
    final countryName = _countryName(countryCode);
    final age = _ageFromBirth(user['date_of_birth']);
    final shortId = displayUserId(user);
    final specialIdLevel = (user['special_id_level'] as num?)?.toInt();
    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = currentUid != null && currentUid == userId;
    final cardUrl = ref.watch(vipCardProvider(vipLevel)).valueOrNull;
    final expectCard = vipLevel > 0 && cardUrl != null && cardUrl.isNotEmpty;
    final gifts = (user['gifts'] as List?) ?? const [];

    final contentTop = expectCard ? 104.0 : (_avatarFrameSize / 2) + 34;

    final avatar = UserFramedAvatar(
      userId: userId,
      avatarUrl: avatarUrl,
      radius: _avatarRadius,
    );

    return _OuterCard(
      vipCardUrl: expectCard ? cardUrl : null,
      avatar: GestureDetector(
        onTap: () => _openFullProfile(context),
        child: avatar,
      ),
      topTrailing: _HeaderIconButton(
        icon: Icons.more_horiz_rounded,
        color: AppColors.textSecondary,
        onTap: () => _openFullProfile(context),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, contentTop, 16, 14),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Long-press to copy: the ID in a room profile could be read
                  // but not taken, so anyone wanting to pass it on had to
                  // retype it from memory.
                  CopyOnLongPress(
                    text: shortId,
                    borderRadius: BorderRadius.circular(10),
                    child: SpecialIdBadge(
                      id: shortId,
                      level: specialIdLevel,
                      height: 20,
                    ),
                  ),
                  if (countryName != null)
                    Text(
                      '|  ${_flagEmoji(countryCode)} $countryName'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              if (gender != null) ...[
                const SizedBox(height: 8),
                _GenderAgeBadge(gender: gender, age: age),
              ],
              const SizedBox(height: 8),
              _MiniBadgesSection(userId: userId),
              if (gifts.isNotEmpty) ...[
                const SizedBox(height: 14),
                _MiniGiftStrip(gifts: gifts),
              ],
              const SizedBox(height: 14),
              if (!isSelf) _buildActionRows(username),
              if (isSelf)
                _RefActionTile(
                  icon: Iconsax.home,
                  label: 'Home',
                  color: const Color(0xFF64B5F6),
                  onTap: () => _openFullProfile(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRows(String profileUsername) {
    final actions = widget.roomActions;
    final showMod = actions?.hasModRow == true;
    final name = profileUsername.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMod) ...[
          Row(
            children: [
              Expanded(
                child: _RefActionTile(
                  icon: Icons.mic_off_rounded,
                  label: 'Mute',
                  color: const Color(0xFFFF5C8A),
                  enabled: actions?.showMute == true && actions?.onMute != null,
                  onTap: () => _runAfterSheetClose(actions?.onMute),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _RefActionTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Ban Chat',
                  color: const Color(0xFF81D4FA),
                  enabled:
                      actions?.showBanChat == true &&
                      actions?.onBanChat != null,
                  onTap: () => _runAfterSheetClose(actions?.onBanChat),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _RefActionTile(
                  icon: Icons.event_seat_outlined,
                  label: 'Stand Up',
                  color: const Color(0xFF81D4FA),
                  enabled:
                      actions?.showStandUp == true &&
                      actions?.onStandUp != null,
                  onTap: () => _runAfterSheetClose(actions?.onStandUp),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _RefActionTile(
                  icon: Icons.pan_tool_alt_outlined,
                  label: 'Kick Out',
                  color: const Color(0xFF81D4FA),
                  enabled: actions?.showKick == true && actions?.onKick != null,
                  onTap: () => _runAfterSheetClose(actions?.onKick),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _RefActionTile(
                icon: Icons.chat_bubble_rounded,
                label: 'Say hi',
                color: const Color(0xFF66BB6A),
                onTap: name.isEmpty
                    ? null
                    : () => _runAfterSheetClose(() {
                        if (actions?.onSayHi != null) {
                          actions!.onSayHi!(name);
                        } else if (widget.onMention != null) {
                          widget.onMention!();
                        }
                      }),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Center(
                child: FollowRelationshipButton(
                  targetUserId: userId,
                  compact: true,
                  onDarkBackground: false,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _RefActionTile(
                icon: Icons.alternate_email_rounded,
                label: 'Reminder',
                color: const Color(0xFFFFCA28),
                onTap: name.isEmpty
                    ? null
                    : () => _runAfterSheetClose(() {
                        if (actions?.onReminder != null) {
                          actions!.onReminder!(name);
                        } else if (widget.onMention != null) {
                          widget.onMention!();
                        }
                      }),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _RefActionTile(
                icon: Icons.card_giftcard_rounded,
                label: 'Send Gift',
                color: const Color(0xFFFFB74D),
                onTap: () => _runAfterSheetClose(
                  widget.onSendGift ?? actions?.onSendGift,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OuterCard extends StatelessWidget {
  const _OuterCard({
    required this.child,
    this.avatar,
    this.topTrailing,
    this.vipCardUrl,
  });

  final Widget child;
  final Widget? avatar;
  final Widget? topTrailing;
  final String? vipCardUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFBF5), AppColors.surface, Color(0xFFFFF8EE)],
            ),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: child,
        ),
        if (vipCardUrl != null)
          Positioned(
            top: -36,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: AppNetworkImage(
                imageUrl: vipCardUrl!,
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
        if (avatar != null) Positioned(top: -28, child: avatar!),
        if (topTrailing != null)
          Positioned(top: 10, right: 12, child: topTrailing!),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _GenderAgeBadge extends StatelessWidget {
  const _GenderAgeBadge({required this.gender, this.age});

  final String gender;
  final int? age;

  @override
  Widget build(BuildContext context) {
    final isMale = gender.toLowerCase() == 'male';
    final color = isMale ? const Color(0xFF4FC3F7) : const Color(0xFFFF80AB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isMale ? Icons.male : Icons.female, size: 14, color: color),
          if (age != null) ...[
            const SizedBox(width: 4),
            Text(
              '$age',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBadgesSection extends ConsumerWidget {
  const _MiniBadgesSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider(userId));
    return badgesAsync.when(
      data: (badges) {
        final shown = badges
            .where((b) => b.type != 'agency' && b.type != 'family')
            .take(10)
            .toList();
        if (shown.isEmpty) return const SizedBox(height: 4);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in shown) UserBadgeChip(badge: b, height: 18),
          ],
        );
      },
      loading: () => const SizedBox(height: 4),
      error: (_, _) => const SizedBox(height: 4),
    );
  }
}

class _MiniGiftStrip extends StatelessWidget {
  const _MiniGiftStrip({required this.gifts});

  final List gifts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gifts.length.clamp(0, 12),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final g = gifts[index] as Map? ?? {};
          final url = g['image_url']?.toString();
          return Container(
            width: 56,
            decoration: ProfileScreenTheme.glassCard(radius: 12),
            padding: const EdgeInsets.all(6),
            child: url != null && url.isNotEmpty
                ? AppNetworkImage(imageUrl: url, fit: BoxFit.contain)
                : const Icon(Icons.card_giftcard, color: AppColors.primary),
          );
        },
      ),
    );
  }
}

class _RefActionTile extends StatelessWidget {
  const _RefActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return Opacity(
      opacity: active ? 1 : 0.35,
      child: InkWell(
        onTap: active
            ? () async {
                await HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
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
