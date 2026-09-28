import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';

enum RoomCategorySlug { chat, party, sing, dj, poetry, game, secret }

class RoomCategory {
  const RoomCategory({
    required this.slug,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  final RoomCategorySlug slug;
  final String label;
  final IconData icon;
  final Color accentColor;

  String get dbValue => slug.name;

  static const List<RoomCategory> all = [
    RoomCategory(
      slug: RoomCategorySlug.chat,
      label: 'Chat',
      icon: Iconsax.messages_2,
      accentColor: AppColors.primary,
    ),
    RoomCategory(
      slug: RoomCategorySlug.party,
      label: 'Party',
      icon: Iconsax.music,
      accentColor: Color(0xFFE040FB),
    ),
    RoomCategory(
      slug: RoomCategorySlug.sing,
      label: 'Sing',
      icon: Iconsax.microphone_2,
      accentColor: Color(0xFFEC407A),
    ),
    RoomCategory(
      slug: RoomCategorySlug.dj,
      label: 'DJ',
      icon: Iconsax.musicnote,
      accentColor: Color(0xFF7E57C2),
    ),
    RoomCategory(
      slug: RoomCategorySlug.poetry,
      label: 'Poetry',
      icon: Iconsax.book_1,
      accentColor: Color(0xFF26A69A),
    ),
    RoomCategory(
      slug: RoomCategorySlug.game,
      label: 'Game',
      icon: Iconsax.game,
      accentColor: Color(0xFF42A5F5),
    ),
    RoomCategory(
      slug: RoomCategorySlug.secret,
      label: 'Secret',
      icon: Iconsax.lock_1,
      accentColor: Color(0xFF78909C),
    ),
  ];

  static RoomCategory? fromDbValue(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final category in all) {
      if (category.dbValue == normalized) return category;
    }
    return null;
  }

  static RoomCategory resolve(String? value) {
    return fromDbValue(value) ?? all.first;
  }

  static String labelFor(String? value) => resolve(value).label;

  static String dbValueFor(String? value) => resolve(value).dbValue;

  static const List<String> roomTabFilterLabels = [
    'Hot',
    'Chat',
    'Party',
    'Sing',
    'DJ',
    'Poetry',
    'Game',
    'Secret',
  ];

  static String? slugForFilterIndex(int index) {
    if (index <= 0 || index > all.length) return null;
    return all[index - 1].dbValue;
  }
}
