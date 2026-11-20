import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/widgets/fast_circle_avatar.dart';
import 'package:sk_live/core/widgets/special_id_badge.dart';
import 'package:sk_live/core/widgets/profile_titles_medals_row.dart';

class MyProfileHeader extends ConsumerWidget {
  const MyProfileHeader({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.displayId,
    this.userId,
    this.specialIdLevel,
    this.gender,
    this.countryCode,
    this.age,
    this.onAvatarTap,
    this.onEditTap,
    this.lightTheme = false,
  });

  final String username;
  final String? avatarUrl;
  final String displayId;
  final String? userId;
  final int? specialIdLevel;
  final String? gender;
  final String? countryCode;
  final int? age;
  final VoidCallback? onAvatarTap;

  final VoidCallback? onEditTap;
  final bool lightTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = MediaQuery.sizeOf(context).width / 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 39 * s),
            GestureDetector(
              onTap: onAvatarTap,
              child: FastCircleAvatar(
                radius: 80 * s,
                imageUrl: avatarUrl,
                backgroundColor: Colors.white,
                fallback: Icon(
                  Iconsax.user,
                  color: Colors.grey.shade400,
                  size: 64 * s,
                ),
              ),
            ),
            SizedBox(width: 29 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 35 * s),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 38 * s,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0A0A0A),
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (onEditTap != null) ...[
                        SizedBox(width: 22 * s),
                        GestureDetector(
                          onTap: onEditTap,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            Iconsax.edit,
                            size: 35 * s,
                            color: const Color(0xFF818E90),
                          ),
                        ),
                      ],
                      SizedBox(width: 24 * s),
                    ],
                  ),
                  Wrap(
                    spacing: 16 * s,
                    runSpacing: 8 * s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (specialIdLevel != null && specialIdLevel! > 0)
                        SpecialIdBadge(
                          id: displayId,
                          level: specialIdLevel,
                          height: 22,
                        )
                      else
                        _IdBadge(
                          id: displayId,
                          scale: s,
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: displayId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ID copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      if (gender != null || age != null)
                        _GenderAgeBadge(gender: gender, age: age),
                      if (countryCode != null && countryCode!.isNotEmpty)
                        Text(
                          Country.parse(countryCode!).flagEmoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (userId != null && userId!.isNotEmpty) ...[
          SizedBox(height: 16 * s),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 39 * s),
            child: ProfileTitlesMedalsRow(userId: userId!, compact: true),
          ),
        ],
      ],
    );
  }
}

class _IdBadge extends StatelessWidget {
  const _IdBadge({required this.id, required this.onCopy, required this.scale});

  final String id;
  final VoidCallback onCopy;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return GestureDetector(
      onTap: onCopy,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ID:$id',
            style: TextStyle(
              fontSize: 26 * s,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF818E90),
              height: 1.2,
            ),
          ),
          SizedBox(width: 8 * s),
          Icon(
            Icons.copy_rounded,
            size: 22 * s,
            color: const Color(0xFF818E90),
          ),
        ],
      ),
    );
  }
}

class _GenderAgeBadge extends StatelessWidget {
  const _GenderAgeBadge({this.gender, this.age});

  final String? gender;
  final int? age;

  @override
  Widget build(BuildContext context) {
    final isMale = gender == 'male';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMale ? const Color(0xFF4FC3F7) : const Color(0xFFFF80AB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMale ? Icons.male_rounded : Icons.female_rounded,
            size: 14,
            color: Colors.white,
          ),
          if (age != null) ...[
            const SizedBox(width: 2),
            Text(
              '$age',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
