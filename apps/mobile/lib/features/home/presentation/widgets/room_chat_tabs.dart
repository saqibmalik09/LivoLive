import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class RoomChatTabs extends StatelessWidget {
  const RoomChatTabs({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  /// One of `all`, `chat`, `gift`.
  final String activeTab;
  final ValueChanged<String> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _RoomChatTabItem(
            title: 'All',
            isSelected: activeTab == 'all',
            onTap: () => onTabSelected('all'),
          ),
          const SizedBox(width: 16),
          _RoomChatTabItem(
            title: context.l10n.room_chat,
            isSelected: activeTab == 'chat',
            onTap: () => onTabSelected('chat'),
          ),
          const SizedBox(width: 16),
          _RoomChatTabItem(
            title: context.l10n.room_gifts,
            isSelected: activeTab == 'gift',
            onTap: () => onTabSelected('gift'),
          ),
        ],
      ),
    );
  }
}

class _RoomChatTabItem extends StatelessWidget {
  const _RoomChatTabItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.yellowAccent : Colors.white38,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.yellowAccent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
