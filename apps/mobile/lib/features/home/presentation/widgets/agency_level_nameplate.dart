import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/string_truncate.dart';

class AgencyLevelNameplate extends StatelessWidget {
  const AgencyLevelNameplate({
    super.key,
    required this.agencyName,
    this.badgeUrl,
    this.height = 22,
    this.maxWidth = 130,
  });

  final String agencyName;
  final String? badgeUrl;
  final double height;
  final double maxWidth;

  static String _shortName(String name, {int maxChars = 8}) {
    return truncateGraphemes(name.trim(), maxChars);
  }

  @override
  Widget build(BuildContext context) {
    final url = badgeUrl?.trim();
    final label = _shortName(agencyName);
    if (url == null || url.isEmpty) {
      return _fallbackChip(label);
    }

    final ideal = height * 4.6;
    final lo = maxWidth < 90 ? maxWidth : 90.0;
    final hi = maxWidth < lo ? lo : maxWidth;
    final width = ideal.clamp(lo, hi);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorWidget: (_, __, ___) => _fallbackChip(label),
            ),
          ),
          Positioned(
            left: width * 0.18,
            right: width * 0.14,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: (height * 0.38).clamp(8.0, 11.0),
                  height: 1.1,
                  shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackChip(String label) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
