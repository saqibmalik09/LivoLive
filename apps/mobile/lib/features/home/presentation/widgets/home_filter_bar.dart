import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/home_rooms_pagination_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class HomeFilterBar extends ConsumerStatefulWidget {
  const HomeFilterBar({super.key});

  @override
  ConsumerState<HomeFilterBar> createState() => _HomeFilterBarState();
}

class _HomeFilterBarState extends ConsumerState<HomeFilterBar> {
  int _activeFilterIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _item('🔥 Popular', 0),
        const SizedBox(width: 12),
        _item('🎉 New', 1),
      ],
    );
  }

  Widget _item(String title, int index) {
    final isActive = _activeFilterIndex == index;
    return GestureDetector(
      onTap: () {
        if (_activeFilterIndex == index) return;
        setState(() => _activeFilterIndex = index);
        ref
            .read(discoveryRoomsPaginationProvider.notifier)
            .setSort(index == 1 ? RoomListSort.newest : RoomListSort.popular);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? (index == 0
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.amber.withValues(alpha: 0.15))
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? (index == 0 ? Colors.green : Colors.amber)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive
                ? (index == 0 ? Colors.green : Colors.amber[800])
                : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
