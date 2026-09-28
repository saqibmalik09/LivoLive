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
  final bool lightTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = lightTheme ? Colors.white : const Color(0xFF1A1A2E);

    return Column(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FastCircleAvatar(
              radius: 36,
              imageUrl: avatarUrl,
              backgroundColor: Colors.white,
              fallback: Icon(
                Iconsax.user,
                color: Colors.grey.shade400,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          username,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (specialIdLevel != null && specialIdLevel! > 0)
              SpecialIdBadge(id: displayId, level: specialIdLevel, height: 22)
            else
              _IdBadge(
                id: displayId,
                lightTheme: lightTheme,
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
        if (userId != null && userId!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProfileTitlesMedalsRow(userId: userId!, compact: true),
        ],
      ],
    );
  }
}

class _IdBadge extends StatelessWidget {
  const _IdBadge({
    required this.id,
    required this.onCopy,
    this.lightTheme = false,
  });

  final String id;
  final VoidCallback onCopy;
  final bool lightTheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCopy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: lightTheme
              ? Colors.white.withValues(alpha: 0.22)
              : const Color(0xFFE8E8EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ID:$id',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: lightTheme ? Colors.white : const Color(0xFF5A5A72),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy_rounded,
              size: 12,
              color: lightTheme ? Colors.white : const Color(0xFF5A5A72),
            ),
          ],
        ),
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
