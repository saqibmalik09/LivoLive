import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/agency_detail_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:sk_live/features/home/presentation/widgets/agency_level_nameplate.dart';
import 'package:sk_live/features/home/presentation/widgets/framed_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyProfileScreen extends ConsumerStatefulWidget {
  const AgencyProfileScreen({super.key, required this.agencyId});

  final String agencyId;

  @override
  ConsumerState<AgencyProfileScreen> createState() =>
      _AgencyProfileScreenState();
}

class _AgencyProfileScreenState extends ConsumerState<AgencyProfileScreen> {
  bool _joining = false;

  static const _headerColor = Color(0xFF1B1F3B);
  static const _pageBg = Color(0xFFF0EBF8);

  String _flag(String? code) {
    if (code == null || code.isEmpty) return '🏳️';
    try {
      return Country.parse(code).flagEmoji;
    } catch (_) {
      return '🏳️';
    }
  }

  String _formatExp(int value) => NumberFormat('#,###').format(value);

  Future<void> _joinAgency(AgencyProfileModel profile) async {
    final userId = ref.read(userProfileProvider).value?['id']?.toString();
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
      return;
    }

    if (userId == profile.owner.userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are the agency owner')));
      return;
    }

    setState(() => _joining = true);
    try {
      final supabase = Supabase.instance.client;

      final existingMember = await supabase
          .from('agency_members')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      if (existingMember != null) {
        throw 'You are already in an agency';
      }

      final pending = await supabase
          .from('agency_applications')
          .select('id')
          .eq('user_id', userId)
          .eq('agency_id', profile.id)
          .eq('status', 'pending')
          .maybeSingle();
      if (pending != null) {
        throw 'Application already pending';
      }

      await supabase.from('agency_applications').insert({
        'user_id': userId,
        'agency_id': profile.id,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.agency_joinRequestSent),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(agencyProfileProvider(widget.agencyId));

    return Scaffold(
      backgroundColor: _pageBg,
      body: Column(
        children: [
          Container(
            color: _headerColor,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Agency',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Iconsax.info_circle,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => asyncErrorWidget(e),
              data: (profile) {
                if (profile == null) {
                  return const Center(child: Text('Agency not found'));
                }
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(agencyProfileProvider(widget.agencyId));
                        await ref.read(
                          agencyProfileProvider(widget.agencyId).future,
                        );
                      },
                      child: ListView(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        children: [
                          _HeroCard(profile: profile, formatExp: _formatExp),
                          const SizedBox(height: 14),
                          _OwnerInfoCard(
                            profile: profile,
                            flag: _flag(profile.owner.countryCode),
                          ),
                          const SizedBox(height: 20),
                          _SectionTitle('Family Star'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _StarCard(
                                  label: 'Honor',
                                  labelColor: const Color(0xFF7B61C7),
                                  member: profile.honorStar,
                                  flag: _flag(profile.honorStar?.countryCode),
                                  frameUrl: profile.honorFrameUrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StarCard(
                                  label: 'Charm',
                                  labelColor: const Color(0xFFFF8A3D),
                                  member: profile.charmStar,
                                  flag: _flag(profile.charmStar?.countryCode),
                                  frameUrl: profile.charmFrameUrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _SectionTitle('Family Room'),
                          const SizedBox(height: 10),
                          if (profile.rooms.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text(
                                  'No rooms yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ...profile.rooms.map(
                              (room) => _FamilyRoomCard(
                                room: room,
                                flag: _flag(room.hostCountryCode),
                                onTap: () {
                                  openRoomLive(context, {
                                    'id': room.roomId,
                                    'title': room.title,
                                    'image_url': room.imageUrl,
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      NavigationUtils.navigateToProfile(
                                        context,
                                        ref,
                                        profile.owner.userId,
                                      ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF3D5AFE),
                                    side: const BorderSide(
                                      color: Color(0xFF3D5AFE),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: const Text(
                                    'Contact Agency',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _joining
                                      ? null
                                      : () => _joinAgency(profile),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B1F3B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: _joining
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Join the Agency',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4A3F72),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile, required this.formatExp});

  final AgencyProfileModel profile;
  final String Function(int) formatExp;

  static const _bannerAsset =
      'assets/ranking/agency/agency_profile_banner.webp';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 278,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            left: -16,
            right: -16,
            height: 138,
            child: ClipPath(
              clipper: _AgencyCurvedBannerClipper(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _bannerAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4A3F72), Color(0xFF1B1F3B)],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 122,
            left: 28,
            right: 28,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 52,
            left: 0,
            right: 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..rotateX(-0.08)
                ..rotateZ(-0.012),
              child: _HeroCardBody(profile: profile, formatExp: formatExp),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCardBody extends StatelessWidget {
  const _HeroCardBody({required this.profile, required this.formatExp});

  final AgencyProfileModel profile;
  final String Function(int) formatExp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3C4), Color(0xFFFFE082), Color(0xFFFFD54F)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FramedAvatar(
                avatarUrl: profile.owner.avatarUrl,
                frameUrl: profile.heroFrameUrl,
                size: 72,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${profile.agencyCode}',
                      style: TextStyle(
                        color: Colors.brown.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.people,
                          size: 14,
                          color: Colors.brown.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.memberCount}',
                          style: TextStyle(
                            color: Colors.brown.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (profile.levelBadgeUrl != null &&
                  profile.levelBadgeUrl!.isNotEmpty)
                AgencyLevelNameplate(
                  agencyName: profile.name,
                  badgeUrl: profile.levelBadgeUrl,
                  height: 22,
                  maxWidth: 130,
                )
              else
                AgencyLevelNameplate(
                  agencyName: profile.name,
                  height: 22,
                  maxWidth: 130,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile.tierName,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.brown.shade700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lv.${profile.level}',
                style: TextStyle(
                  color: Colors.brown.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Lv.${profile.nextLevel}',
                style: TextStyle(
                  color: Colors.brown.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: profile.levelProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation(Colors.brown.shade600),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exp: ${formatExp(profile.totalExp)} / ${formatExp(profile.expForNextLevel)}',
            style: TextStyle(color: Colors.brown.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AgencyCurvedBannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 32)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 22,
        0,
        size.height - 32,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _OwnerInfoCard extends StatelessWidget {
  const _OwnerInfoCard({required this.profile, required this.flag});

  final AgencyProfileModel profile;
  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AvatarCircle(url: profile.owner.avatarUrl, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            profile.owner.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3C4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Owner',
                            style: TextStyle(
                              color: Color(0xFFB8860B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Iconsax.medal,
                            size: 12,
                            color: Color(0xFF3D5AFE),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.owner.wealthLevel}',
                            style: const TextStyle(
                              color: Color(0xFF3D5AFE),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    profile.announcement ?? '',
                    style: const TextStyle(
                      color: Color(0xFF4A6FA5),
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(
                  Iconsax.volume_high,
                  color: Color(0xFF3D5AFE),
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarCard extends StatelessWidget {
  const _StarCard({
    required this.label,
    required this.labelColor,
    required this.member,
    required this.flag,
    this.frameUrl,
  });

  final String label;
  final Color labelColor;
  final AgencyMemberPreview? member;
  final String flag;
  final String? frameUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: labelColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FramedAvatar(
            avatarUrl: member?.avatarUrl,
            frameUrl: frameUrl,
            size: 56,
          ),
          const SizedBox(height: 8),
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            member?.username ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyRoomCard extends StatelessWidget {
  const _FamilyRoomCard({
    required this.room,
    required this.flag,
    required this.onTap,
  });

  final AgencyRoomPreview room;
  final String flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 64,
                color: const Color(0xFFF3F0FA),
                child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: room.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.meeting_room,
                        color: Colors.grey,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.hostUsername,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Room No: ${room.roomLabel}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(Iconsax.chart, color: Color(0xFF3D5AFE), size: 18),
                Text(
                  '${room.onlineCount}',
                  style: const TextStyle(
                    color: Color(0xFF3D5AFE),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD54F), width: 2),
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Icon(Icons.person, size: size * 0.5),
              )
            : Icon(Icons.person, size: size * 0.5, color: Colors.grey),
      ),
    );
  }
}
