import 'package:flutter/material.dart';
import 'package:sk_live/core/models/room_category.dart';
import 'package:sk_live/core/theme/app_colors.dart';

typedef RoomCategorySelected = void Function(String slug);

Future<void> showRoomCategoryPickerSheet({
  required BuildContext context,
  required String currentSlug,
  required RoomCategorySelected onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => RoomCategoryPickerSheet(
      currentSlug: currentSlug,
      onSelected: (slug) {
        Navigator.pop(context);
        onSelected(slug);
      },
    ),
  );
}

class RoomCategoryPickerSheet extends StatelessWidget {
  const RoomCategoryPickerSheet({
    super.key,
    required this.currentSlug,
    required this.onSelected,
  });

  final String currentSlug;
  final RoomCategorySelected onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose room topic',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick a category for your room. This helps others find you on the Room tab.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: RoomCategory.all.length,
            itemBuilder: (context, index) {
              final category = RoomCategory.all[index];
              final isSelected = category.dbValue == currentSlug;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(category.dbValue),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                category.accentColor.withValues(alpha: 0.22),
                                AppColors.primaryLight.withValues(alpha: 0.35),
                              ],
                            )
                          : null,
                      color: isSelected ? null : AppColors.primaryUltraLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? AppColors.cardShadow : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          category.icon,
                          color: isSelected
                              ? category.accentColor
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            category.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
