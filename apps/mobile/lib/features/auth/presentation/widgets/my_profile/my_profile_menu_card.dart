import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class MyProfileMenuCard extends StatelessWidget {
  const MyProfileMenuCard({super.key, required this.items});

  final List<MyProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 56, color: Colors.grey.shade200),
              _MenuRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class MyProfileMenuItem {
  const MyProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final MyProfileMenuItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(item.icon, color: const Color(0xFF1A1A2E), size: 22),
      title: Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF1A1A2E),
        ),
      ),
      subtitle: item.subtitle == null || item.subtitle!.isEmpty
          ? null
          : Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
      trailing: Icon(
        Iconsax.arrow_right_3,
        size: 16,
        color: Colors.grey.shade400,
      ),
    );
  }
}

class MyProfileStandaloneMenuTile extends StatelessWidget {
  const MyProfileStandaloneMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(icon, color: const Color(0xFF1A1A2E), size: 22),
          title: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF1A1A2E),
            ),
          ),
          trailing: Icon(
            Iconsax.arrow_right_3,
            size: 16,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
