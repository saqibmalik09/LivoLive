import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class MyProfileMenuCard extends StatelessWidget {
  const MyProfileMenuCard({super.key, required this.items});

  final List<MyProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 750;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30 * s),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30 * s),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (final item in items) _MenuRow(item: item, scale: s),
            ],
          ),
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
    this.colors,
    this.asset,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  /// Two-stop gradient for the icon badge, light stop first. These rows used a
  /// flat near-black glyph while every tile above them carries a coloured
  /// badge, which left three stray black marks at the bottom of the page.
  final List<Color>? colors;

  final String? asset;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.scale});

  final MyProfileMenuItem item;
  final double scale;

  static const Color _teal = Color(0xFF195C51);
  static const Color _chevron = Color(0xFF1E6657);

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final subtitle = item.subtitle;
    return InkWell(
      onTap: item.onTap,
      child: SizedBox(
        height: 103 * s,
        child: Row(
          children: [
            SizedBox(width: 29 * s),
            SizedBox.square(
              dimension: 48 * s,
              child: item.asset != null
                  ? Image.asset(item.asset!, fit: BoxFit.contain)
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12 * s),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors:
                              item.colors ??
                              const [Color(0xFFB79BFF), Color(0xFF6435C9)],
                        ),
                      ),
                      child: Icon(item.icon, color: Colors.white, size: 28 * s),
                    ),
            ),
            SizedBox(width: 17 * s),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 33 * s,
                  color: _teal,
                  height: 1.2,
                ),
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              SizedBox(width: 12 * s),
              Text(
                subtitle,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 26 * s,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF818E90),
                  height: 1.2,
                ),
              ),
            ],
            SizedBox(width: 8 * s),
            Icon(Icons.chevron_right_rounded, size: 40 * s, color: _chevron),
            SizedBox(width: 25 * s),
          ],
        ),
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
